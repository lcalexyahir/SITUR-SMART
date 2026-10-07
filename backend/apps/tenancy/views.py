from django.db.models import Prefetch
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.rbac.services import is_superadmin, require_permission, require_tenant_access

from .models import Plan, Subscription
from .serializers import (
    AssignSubscriptionSerializer,
    PlanSerializer,
    RenewSubscriptionSerializer,
    SubscriptionSerializer,
    TenantDetailSerializer,
    TenantSerializer,
    TenantStatusSerializer,
    TenantSubscriptionStatusSerializer,
    TenantUpdateSerializer,
)
from .services import (
    assign_subscription,
    change_tenant_status,
    city_labels,
    expire_due_subscriptions,
    get_active_subscription,
    get_tenant,
    renew_subscription,
    require_system_admin,
    subscription_history,
    suspend_subscription,
    update_tenant,
    visible_tenants,
)


def _subscriptions_prefetch():
    return Prefetch(
        "subscriptions",
        queryset=Subscription.objects.select_related("plan").order_by("-created_at"),
    )


def _detail_response(request, tenant_id: int):
    expire_due_subscriptions([tenant_id])
    tenant = (
        visible_tenants(request.user)
        .prefetch_related(_subscriptions_prefetch())
        .filter(pk=tenant_id)
        .first()
    )
    if tenant is None:
        tenant = get_tenant(tenant_id)
    context = {"request": request, "city_labels": city_labels([tenant.city_id])}
    return Response(TenantDetailSerializer(tenant, context=context).data)


class TenantListCreateView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=TenantSerializer(many=True))
    def get(self, request):
        expire_due_subscriptions()
        tenants = list(
            visible_tenants(request.user).prefetch_related(_subscriptions_prefetch()).order_by("trade_name")
        )
        context = {"request": request, "city_labels": city_labels(t.city_id for t in tenants)}
        return Response(TenantSerializer(tenants, many=True, context=context).data)

    @extend_schema(
        request=TenantSerializer,
        responses={201: TenantSerializer},
    )
    def post(self, request):
        require_permission(request.user, "TENANTS_GESTIONAR")
        serializer = TenantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        tenant = serializer.save()
        return Response(TenantSerializer(tenant).data, status=status.HTTP_201_CREATED)


class TenantDetailView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=TenantDetailSerializer)
    def get(self, request, pk):
        get_tenant(pk)
        require_tenant_access(request.user, pk)
        return _detail_response(request, pk)

    @extend_schema(request=TenantUpdateSerializer, responses=TenantDetailSerializer)
    def put(self, request, pk):
        return self._update(request, pk, partial=False)

    @extend_schema(request=TenantUpdateSerializer, responses=TenantDetailSerializer)
    def patch(self, request, pk):
        return self._update(request, pk, partial=True)

    def _update(self, request, pk, partial: bool):
        tenant = get_tenant(pk)
        require_tenant_access(request.user, tenant.id)
        serializer = TenantUpdateSerializer(tenant, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        update_tenant(actor=request.user, tenant=tenant, data=dict(serializer.validated_data), request=request)
        return _detail_response(request, tenant.id)


class TenantStatusView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(request=TenantStatusSerializer, responses=TenantDetailSerializer)
    def post(self, request, pk):
        serializer = TenantStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        change_tenant_status(
            actor=request.user,
            tenant_id=pk,
            status=serializer.validated_data["estado"],
            request=request,
        )
        return _detail_response(request, pk)


class PlanListView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=PlanSerializer(many=True))
    def get(self, request):
        require_system_admin(request.user)
        plans = Plan.objects.select_related("currency").filter(active=True).order_by("monthly_price")
        return Response(PlanSerializer(plans, many=True).data)


class TenantSubscriptionView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=TenantSubscriptionStatusSerializer)
    def get(self, request, pk):
        tenant = get_tenant(pk)
        require_tenant_access(request.user, tenant.id)
        current = get_active_subscription(tenant.id)
        history = subscription_history(tenant.id)
        return Response(
            {
                "tenant": {
                    "id": tenant.id,
                    "nombre_comercial": tenant.trade_name,
                    "estado": tenant.status,
                },
                "actual": SubscriptionSerializer(current).data if current else None,
                "historial": SubscriptionSerializer(history, many=True).data,
                "puede_gestionar": is_superadmin(request.user),
            }
        )


class AssignSubscriptionView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(request=AssignSubscriptionSerializer, responses={201: SubscriptionSerializer})
    def post(self, request, pk):
        serializer = AssignSubscriptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription = assign_subscription(
            actor=request.user,
            tenant_id=pk,
            plan_id=serializer.validated_data["plan_id"],
            months=serializer.validated_data["meses"],
            auto_renew=serializer.validated_data["renovacion_automatica"],
            request=request,
        )
        return Response(SubscriptionSerializer(subscription).data, status=status.HTTP_201_CREATED)


class RenewSubscriptionView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(request=RenewSubscriptionSerializer, responses=SubscriptionSerializer)
    def post(self, request, pk):
        serializer = RenewSubscriptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription = renew_subscription(
            actor=request.user,
            tenant_id=pk,
            months=serializer.validated_data["meses"],
            request=request,
        )
        return Response(SubscriptionSerializer(subscription).data)


class SuspendSubscriptionView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses=SubscriptionSerializer)
    def post(self, request, pk):
        subscription = suspend_subscription(actor=request.user, tenant_id=pk, request=request)
        return Response(SubscriptionSerializer(subscription).data)