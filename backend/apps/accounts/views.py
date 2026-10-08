from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.rbac.models import Role, UserRole
from apps.tenancy.models import Tenant

from .models import User
from .serializers import (
    AuthResponseSerializer,
    ChangePasswordSerializer,
    LoginSerializer,
    ProfileSerializer,
    RefreshSerializer,
    RegisterClientSerializer,
    UserContextSerializer,
    UserManagementSerializer,
)
from .services import (
    change_password,
    login_user,
    profile_data,
    register_client,
    revoke_refresh_token,
    rotate_refresh_token,
    update_profile,
)


class LoginView(APIView):
    permission_classes = (AllowAny,)

    @extend_schema(request=LoginSerializer, responses=AuthResponseSerializer)
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tokens = login_user(request=request, **serializer.validated_data)
        return Response({**tokens, "user": UserContextSerializer(user).data})


class RegisterView(APIView):
    """Registro publico de clientes (viajeros). Devuelve la sesion iniciada."""

    permission_classes = (AllowAny,)
    authentication_classes = ()

    @extend_schema(request=RegisterClientSerializer, responses={201: AuthResponseSerializer})
    def post(self, request):
        serializer = RegisterClientSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tokens = register_client(data=serializer.validated_data, request=request)
        return Response(
            {**tokens, "user": UserContextSerializer(user).data},
            status=status.HTTP_201_CREATED,
        )


class RefreshView(APIView):
    permission_classes = (AllowAny,)

    @extend_schema(request=RefreshSerializer, responses=AuthResponseSerializer)
    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, tokens = rotate_refresh_token(
            raw_refresh=serializer.validated_data["refresh"], request=request
        )
        return Response({**tokens, "user": UserContextSerializer(user).data})


class LogoutView(APIView):
    permission_classes = (AllowAny,)

    @extend_schema(request=RefreshSerializer, responses={204: None})
    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        revoke_refresh_token(serializer.validated_data["refresh"], request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=UserContextSerializer)
    def get(self, request):
        return Response(UserContextSerializer(request.user).data)


class ProfileView(APIView):
    """'Mi perfil': datos personales y, para clientes, su documento."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ProfileSerializer)
    def get(self, request):
        return Response(ProfileSerializer(profile_data(request.user)).data)

    @extend_schema(request=ProfileSerializer, responses=ProfileSerializer)
    def put(self, request):
        serializer = ProfileSerializer(data=request.data, context={"user": request.user})
        serializer.is_valid(raise_exception=True)
        data = update_profile(user=request.user, data=serializer.validated_data, request=request)
        return Response(ProfileSerializer(data).data)


class ChangePasswordView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(request=ChangePasswordSerializer, responses={200: None})
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={"user": request.user})
        serializer.is_valid(raise_exception=True)
        change_password(user=request.user, new_password=serializer.validated_data["nueva"], request=request)
        return Response({"detalle": "Contraseña actualizada correctamente."})


class UserListCreateView(ListCreateAPIView):
    permission_classes = (IsAuthenticated,)
    queryset = User.objects.all()
    serializer_class = UserManagementSerializer

    def perform_create(self, serializer):
        data = serializer.validated_data
        user = User.objects.create_user(
            email=data["email"],
            password=self.request.data.get("password"),
            first_names=data["first_names"],
            last_names=data["last_names"],
            phone=data.get("phone"),
            status=data.get(
                "status",
                User.Status.ACTIVE,
            ),
        )
        role_id = self.request.data.get("role_id")
        tenant_id = self.request.data.get("tenant_id")
        if role_id:
            role = Role.objects.get(
                id=role_id
            )
            tenant = None
            if tenant_id:
                tenant = Tenant.objects.get(
                    id=tenant_id
                )
            UserRole.objects.create(
                user=user,
                role=role,
                tenant=tenant,
            )


class UserDetailView(RetrieveUpdateDestroyAPIView):
    permission_classes = (IsAuthenticated,)
    queryset = User.objects.all()
    serializer_class = UserManagementSerializer