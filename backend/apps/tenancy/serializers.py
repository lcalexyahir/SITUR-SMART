from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.rbac.services import is_superadmin

from .models import Plan, Subscription, Tenant
from .services import MANAGEABLE_STATUSES, tenant_owner, today


class TenantSubscriptionSummarySerializer(serializers.Serializer):
    estado = serializers.CharField()
    plan = serializers.CharField()
    fecha_fin = serializers.DateField(allow_null=True)


class TenantOwnerSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nombre = serializers.CharField()
    email = serializers.EmailField()


class TenantSerializer(serializers.ModelSerializer):
    nombre_comercial = serializers.CharField(source="trade_name")
    razon_social = serializers.CharField(source="legal_name")
    estado = serializers.CharField(source="status")
    nit = serializers.CharField(source="tax_id", allow_null=True, required=False)
    email_contacto = serializers.EmailField(source="contact_email", allow_null=True, required=False)
    telefono = serializers.CharField(source="phone", allow_null=True, required=False)
    ciudad = serializers.SerializerMethodField()
    creado_en = serializers.DateTimeField(source="created_at", read_only=True)
    suscripcion = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = (
            "id",
            "nombre_comercial",
            "razon_social",
            "subdomain",
            "nit",
            "email_contacto",
            "telefono",
            "estado",
            "ciudad",
            "creado_en",
            "suscripcion",
        )

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_ciudad(self, tenant):
        return self.context.get("city_labels", {}).get(tenant.city_id)

    @extend_schema_field(TenantSubscriptionSummarySerializer(allow_null=True))
    def get_suscripcion(self, tenant):
        subscriptions = list(tenant.subscriptions.all())
        if not subscriptions:
            return None
        current = next(
            (item for item in subscriptions if item.status == Subscription.Status.ACTIVE),
            subscriptions[0],
        )
        return {
            "estado": current.status,
            "plan": current.plan.name,
            "fecha_fin": current.end_date.isoformat() if current.end_date else None,
        }


class TenantDetailSerializer(TenantSerializer):
    propietario = serializers.SerializerMethodField()
    puede_gestionar = serializers.SerializerMethodField()

    class Meta(TenantSerializer.Meta):
        fields = TenantSerializer.Meta.fields + ("propietario", "puede_gestionar")

    @extend_schema_field(TenantOwnerSerializer(allow_null=True))
    def get_propietario(self, tenant):
        owner = tenant_owner(tenant.id)
        if owner is None:
            return None
        return {"id": owner.id, "nombre": owner.get_full_name(), "email": owner.email}

    @extend_schema_field(serializers.BooleanField())
    def get_puede_gestionar(self, tenant):
        request = self.context.get("request")
        return bool(request and is_superadmin(request.user))


class TenantUpdateSerializer(serializers.ModelSerializer):
    nombre_comercial = serializers.CharField(source="trade_name", max_length=180)
    razon_social = serializers.CharField(source="legal_name", max_length=180)
    subdomain = serializers.RegexField(
        regex=r"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$",
        max_length=80,
        error_messages={"invalid": "Use solo minúsculas, números y guiones (mínimo 3 caracteres)."},
    )
    nit = serializers.CharField(source="tax_id", max_length=30, allow_null=True, allow_blank=True, required=False)
    email_contacto = serializers.EmailField(
        source="contact_email", allow_null=True, allow_blank=True, required=False
    )
    telefono = serializers.CharField(source="phone", max_length=30, allow_null=True, allow_blank=True, required=False)

    class Meta:
        model = Tenant
        fields = ("nombre_comercial", "razon_social", "subdomain", "nit", "email_contacto", "telefono")

    def validate(self, attrs):
        for field in ("tax_id", "contact_email", "phone"):
            if attrs.get(field) == "":
                attrs[field] = None

        others = Tenant.objects.exclude(pk=self.instance.pk) if self.instance else Tenant.objects.all()

        subdomain = attrs.get("subdomain")
        if subdomain and others.filter(subdomain__iexact=subdomain).exists():
            raise serializers.ValidationError({"subdomain": "Ese identificador web ya está en uso."})

        tax_id = attrs.get("tax_id")
        if tax_id and others.filter(tax_id=tax_id).exists():
            raise serializers.ValidationError({"nit": "Ese NIT ya está registrado en otra empresa."})

        return attrs


class TenantStatusSerializer(serializers.Serializer):
    estado = serializers.ChoiceField(choices=[status.value for status in MANAGEABLE_STATUSES])


class PlanSerializer(serializers.ModelSerializer):
    codigo = serializers.CharField(source="code")
    nombre = serializers.CharField(source="name")
    precio_mensual = serializers.DecimalField(source="monthly_price", max_digits=12, decimal_places=2)
    moneda = serializers.CharField(source="currency.symbol")
    max_usuarios = serializers.IntegerField(source="max_users")

    class Meta:
        model = Plan
        fields = ("id", "codigo", "nombre", "precio_mensual", "moneda", "max_usuarios")


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = PlanSerializer(read_only=True)
    fecha_inicio = serializers.DateField(source="start_date")
    fecha_fin = serializers.DateField(source="end_date", allow_null=True)
    estado = serializers.CharField(source="status")
    renovacion_automatica = serializers.BooleanField(source="auto_renew")
    dias_restantes = serializers.SerializerMethodField()
    creado_en = serializers.DateTimeField(source="created_at")

    class Meta:
        model = Subscription
        fields = (
            "id",
            "plan",
            "fecha_inicio",
            "fecha_fin",
            "estado",
            "renovacion_automatica",
            "dias_restantes",
            "creado_en",
        )

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_dias_restantes(self, subscription):
        if subscription.status != Subscription.Status.ACTIVE or subscription.end_date is None:
            return None
        return max((subscription.end_date - today()).days, 0)


class TenantBasicSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nombre_comercial = serializers.CharField()
    estado = serializers.CharField()


class TenantSubscriptionStatusSerializer(serializers.Serializer):
    tenant = TenantBasicSerializer()
    actual = SubscriptionSerializer(allow_null=True)
    historial = SubscriptionSerializer(many=True)
    puede_gestionar = serializers.BooleanField()


class AssignSubscriptionSerializer(serializers.Serializer):
    plan_id = serializers.IntegerField(min_value=1)
    meses = serializers.IntegerField(min_value=1, max_value=36)
    renovacion_automatica = serializers.BooleanField(required=False, default=False)


class RenewSubscriptionSerializer(serializers.Serializer):
    meses = serializers.IntegerField(min_value=1, max_value=36)