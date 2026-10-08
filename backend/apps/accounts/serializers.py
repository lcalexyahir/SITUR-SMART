from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.rbac.models import UserRole
from apps.tenancy.models import UserTenant

from .models import ClientProfile, User


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField(write_only=True, trim_whitespace=False)


class TenantContextSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    subdomain = serializers.CharField()


class UserContextSerializer(serializers.ModelSerializer):
    nombres = serializers.CharField(source="first_names")
    apellidos = serializers.CharField(source="last_names")
    estado = serializers.CharField(source="status")
    roles = serializers.SerializerMethodField()
    permisos = serializers.SerializerMethodField()
    tenants = serializers.SerializerMethodField()
    es_cliente = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "email", "nombres", "apellidos", "estado", "roles", "permisos", "tenants", "es_cliente")

    @extend_schema_field(serializers.ListField(child=serializers.CharField()))
    def get_roles(self, user):
        return list(
            UserRole.objects.filter(user=user)
            .order_by("role__code")
            .values_list("role__code", flat=True)
            .distinct()
        )

    @extend_schema_field(serializers.ListField(child=serializers.CharField()))
    def get_permisos(self, user):
        return list(
            UserRole.objects.filter(user=user)
            .order_by("role__role_permissions__permission__code")
            .values_list("role__role_permissions__permission__code", flat=True)
            .exclude(role__role_permissions__permission__code__isnull=True)
            .distinct()
        )

    @extend_schema_field(TenantContextSerializer(many=True))
    def get_tenants(self, user):
        memberships = UserTenant.objects.select_related("tenant").filter(
            user=user, status=UserTenant.Status.ACTIVE
        )
        return [
            {
                "id": membership.tenant_id,
                "name": membership.tenant.trade_name,
                "subdomain": membership.tenant.subdomain,
            }
            for membership in memberships
        ]

    @extend_schema_field(serializers.BooleanField())
    def get_es_cliente(self, user):
        return ClientProfile.objects.filter(user=user).exists()


class AuthResponseSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    user = UserContextSerializer()


class UserManagementSerializer(serializers.ModelSerializer):
    nombres = serializers.CharField(
        source="first_names"
    )
    apellidos = serializers.CharField(
        source="last_names"
    )
    telefono = serializers.CharField(
        source="phone",
        allow_blank=True,
        required=False,
    )
    estado = serializers.CharField(
        source="status"
    )

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "nombres",
            "apellidos",
            "telefono",
            "estado",
        )


# ---------------------------------------------------------------------------
# Clientes (viajeros)
# ---------------------------------------------------------------------------

DOCUMENT_TYPES = [choice.value for choice in ClientProfile.DocumentType]


def _validate_document(attrs: dict, exclude_user_id: int | None = None) -> dict:
    """Tipo y numero de documento van juntos y no pueden repetirse."""
    document_type = (attrs.get("tipo_documento") or "").strip() or None
    document_number = (attrs.get("numero_documento") or "").strip() or None

    if bool(document_type) != bool(document_number):
        raise serializers.ValidationError(
            {"numero_documento": "Indique el tipo y el número de documento, o deje ambos vacíos."}
        )

    if document_type and document_number:
        duplicated = ClientProfile.objects.filter(
            document_type=document_type, document_number=document_number
        )
        if exclude_user_id is not None:
            duplicated = duplicated.exclude(user_id=exclude_user_id)
        if duplicated.exists():
            raise serializers.ValidationError(
                {"numero_documento": "Ese documento ya está registrado en otra cuenta."}
            )

    attrs["tipo_documento"] = document_type
    attrs["numero_documento"] = document_number
    return attrs


class RegisterClientSerializer(serializers.Serializer):
    nombres = serializers.CharField(max_length=120)
    apellidos = serializers.CharField(max_length=120)
    email = serializers.EmailField(max_length=255)
    telefono = serializers.CharField(max_length=30, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, trim_whitespace=False)
    tipo_documento = serializers.ChoiceField(choices=DOCUMENT_TYPES, required=False, allow_blank=True)
    numero_documento = serializers.CharField(max_length=50, required=False, allow_blank=True)

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("Ya existe una cuenta con ese correo.")
        return email

    def validate(self, attrs):
        attrs["nombres"] = attrs["nombres"].strip()
        attrs["apellidos"] = attrs["apellidos"].strip()
        attrs["telefono"] = (attrs.get("telefono") or "").strip() or None

        candidate = User(
            email=attrs["email"],
            first_names=attrs["nombres"],
            last_names=attrs["apellidos"],
        )
        try:
            validate_password(attrs["password"], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc

        return _validate_document(attrs)


class ProfileSerializer(serializers.Serializer):
    """Datos de 'Mi perfil'. Los campos de documento solo aplican a clientes."""

    id = serializers.IntegerField(read_only=True)
    email = serializers.EmailField(read_only=True)
    nombres = serializers.CharField(max_length=120)
    apellidos = serializers.CharField(max_length=120)
    telefono = serializers.CharField(max_length=30, required=False, allow_blank=True, allow_null=True)
    es_cliente = serializers.BooleanField(read_only=True)
    tipo_documento = serializers.ChoiceField(
        choices=DOCUMENT_TYPES, required=False, allow_blank=True, allow_null=True
    )
    numero_documento = serializers.CharField(max_length=50, required=False, allow_blank=True, allow_null=True)
    fecha_nacimiento = serializers.DateField(required=False, allow_null=True)

    def validate(self, attrs):
        attrs["nombres"] = attrs["nombres"].strip()
        attrs["apellidos"] = attrs["apellidos"].strip()
        attrs["telefono"] = (attrs.get("telefono") or "").strip() or None
        user = self.context["user"]
        if ClientProfile.objects.filter(user=user).exists():
            return _validate_document(attrs, exclude_user_id=user.id)
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    actual = serializers.CharField(write_only=True, trim_whitespace=False)
    nueva = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs):
        user = self.context["user"]
        if not user.check_password(attrs["actual"]):
            raise serializers.ValidationError({"actual": "La contraseña actual no es correcta."})
        if attrs["actual"] == attrs["nueva"]:
            raise serializers.ValidationError({"nueva": "La nueva contraseña debe ser distinta de la actual."})
        try:
            validate_password(attrs["nueva"], user=user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"nueva": list(exc.messages)}) from exc
        return attrs