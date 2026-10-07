import calendar
from datetime import date

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

from apps.audit.services import record_audit
from apps.rbac.models import UserRole
from apps.rbac.services import is_superadmin, require_permission

from .exceptions import SubscriptionInactive, TenantNotOperational, TenantReadOnly
from .models import City, Plan, Subscription, Tenant, UserTenant

SAFE_METHODS = ("GET", "HEAD", "OPTIONS")

# Estados en los que los usuarios de la empresa pueden ingresar.
# SUSPENDIDO: ingresan, pero solo pueden consultar (no registrar cambios).
OPERATIONAL_STATUSES = (Tenant.Status.ACTIVE, Tenant.Status.SUSPENDED)

# Estados que el SuperAdmin puede asignar desde "Estado operativo".
MANAGEABLE_STATUSES = (Tenant.Status.ACTIVE, Tenant.Status.SUSPENDED, Tenant.Status.INACTIVE)

# Pistas para identificar al propietario por el codigo de su rol en la empresa.
OWNER_ROLE_HINTS = ("PROPIETARIO", "OWNER", "ADMIN", "JEFE")


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------


def today() -> date:
    return timezone.localdate()


def add_months(start: date, months: int) -> date:
    month_index = start.month - 1 + months
    year = start.year + month_index // 12
    month = month_index % 12 + 1
    day = min(start.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def require_system_admin(user) -> None:
    if not is_superadmin(user):
        raise PermissionDenied("Solo el administrador del sistema puede realizar esta operación.")


def get_tenant(tenant_id: int) -> Tenant:
    try:
        return Tenant.objects.get(pk=tenant_id)
    except Tenant.DoesNotExist as exc:
        raise NotFound("La empresa no existe.") from exc


def user_tenant_ids(user) -> list[int]:
    return list(
        UserTenant.objects.filter(user=user, status=UserTenant.Status.ACTIVE).values_list("tenant_id", flat=True)
    )


def visible_tenants(user):
    """El SuperAdmin ve todas las empresas; los demas, solo las suyas."""
    if is_superadmin(user):
        return Tenant.objects.all()
    return Tenant.objects.filter(id__in=user_tenant_ids(user))


def city_labels(city_ids) -> dict[int, str]:
    ids = {city_id for city_id in city_ids if city_id}
    if not ids:
        return {}
    return {
        city.id: f"{city.name}, {city.country.name}"
        for city in City.objects.select_related("country").filter(id__in=ids)
    }


def tenant_owner(tenant_id: int):
    """
    Devuelve el usuario responsable de la empresa: el primero con un rol de la
    empresa cuyo codigo indique administracion; si no hay, el primer miembro.
    """
    assignments = list(
        UserRole.objects.select_related("user", "role").filter(tenant_id=tenant_id).order_by("assigned_at")
    )
    for hint in OWNER_ROLE_HINTS:
        for assignment in assignments:
            if hint in assignment.role.code.upper():
                return assignment.user

    membership = (
        UserTenant.objects.select_related("user").filter(tenant_id=tenant_id).order_by("created_at").first()
    )
    return membership.user if membership else None


# ---------------------------------------------------------------------------
# Suscripciones
# ---------------------------------------------------------------------------


def expire_due_subscriptions(tenant_ids: list[int] | None = None) -> int:
    """Marca como VENCIDA toda suscripcion ACTIVA cuya fecha_fin ya paso."""
    queryset = Subscription.objects.filter(
        status=Subscription.Status.ACTIVE,
        end_date__isnull=False,
        end_date__lt=today(),
    )
    if tenant_ids is not None:
        queryset = queryset.filter(tenant_id__in=tenant_ids)
    return queryset.update(status=Subscription.Status.EXPIRED)


def get_active_subscription(tenant_id: int) -> Subscription | None:
    expire_due_subscriptions([tenant_id])
    return (
        Subscription.objects.select_related("plan", "plan__currency")
        .filter(tenant_id=tenant_id, status=Subscription.Status.ACTIVE)
        .first()
    )


def subscription_history(tenant_id: int, limit: int = 20):
    return (
        Subscription.objects.select_related("plan", "plan__currency")
        .filter(tenant_id=tenant_id)
        .order_by("-created_at")[:limit]
    )


# ---------------------------------------------------------------------------
# Control de acceso SaaS
# ---------------------------------------------------------------------------


def ensure_tenant_access(user, tenant_id: int | None = None, method: str = "GET") -> None:
    """
    Reglas del modelo SaaS (el SuperAdmin nunca se bloquea):
    1. La empresa debe estar ACTIVA o SUSPENDIDA. Si esta PENDIENTE o
       INACTIVA, sus usuarios no ingresan (403 empresa_no_habilitada).
    2. La empresa debe tener una suscripcion ACTIVA (402 suscripcion_inactiva).
    3. Si la empresa esta SUSPENDIDA, sus usuarios solo pueden consultar
       (403 empresa_suspendida en operaciones que modifican datos).
    Los usuarios sin empresa (por ejemplo, clientes) no se bloquean.
    """
    if is_superadmin(user):
        return

    tenant_ids = [tenant_id] if tenant_id is not None else user_tenant_ids(user)
    if not tenant_ids:
        return

    tenants = dict(Tenant.objects.filter(id__in=tenant_ids).values_list("id", "status"))
    if not tenants:
        return

    operational = {tid: status for tid, status in tenants.items() if status in OPERATIONAL_STATUSES}
    if not operational:
        raise TenantNotOperational()

    expire_due_subscriptions(list(operational))
    subscribed = set(
        Subscription.objects.filter(
            tenant_id__in=list(operational), status=Subscription.Status.ACTIVE
        ).values_list("tenant_id", flat=True)
    )
    if not subscribed:
        raise SubscriptionInactive()

    if method.upper() not in SAFE_METHODS and all(
        operational[tid] == Tenant.Status.SUSPENDED for tid in subscribed
    ):
        raise TenantReadOnly()


# ---------------------------------------------------------------------------
# Empresas
# ---------------------------------------------------------------------------


def _tenant_snapshot(tenant: Tenant) -> dict:
    return {
        "nombre_comercial": tenant.trade_name,
        "razon_social": tenant.legal_name,
        "subdomain": tenant.subdomain,
        "nit": tenant.tax_id,
        "email_contacto": tenant.contact_email,
        "telefono": tenant.phone,
        "estado": tenant.status,
    }


@transaction.atomic
def update_tenant(*, actor, tenant: Tenant, data: dict, request=None) -> Tenant:
    require_permission(actor, "TENANTS_GESTIONAR", tenant.id)
    if not data:
        return tenant

    previous = _tenant_snapshot(tenant)
    for field, value in data.items():
        setattr(tenant, field, value)
    tenant.save(update_fields=list(data.keys()))

    record_audit(
        actor=actor,
        tenant_id=tenant.id,
        action="EDITAR",
        entity="tenant",
        entity_id=str(tenant.id),
        previous_data=previous,
        new_data=_tenant_snapshot(tenant),
        request=request,
    )
    return tenant


@transaction.atomic
def change_tenant_status(*, actor, tenant_id: int, status: str, request=None) -> Tenant:
    require_system_admin(actor)
    tenant = Tenant.objects.select_for_update().filter(pk=tenant_id).first()
    if tenant is None:
        raise NotFound("La empresa no existe.")
    if status not in MANAGEABLE_STATUSES:
        raise ValidationError({"estado": "Estado no permitido."})
    if tenant.status == status:
        return tenant

    previous = tenant.status
    tenant.status = status
    tenant.save(update_fields=["status"])

    record_audit(
        actor=actor,
        tenant_id=tenant.id,
        action="CAMBIAR_ESTADO",
        entity="tenant",
        entity_id=str(tenant.id),
        previous_data={"estado": previous},
        new_data={"estado": status},
        request=request,
    )
    return tenant


# ---------------------------------------------------------------------------
# Gestion de suscripciones (solo SuperAdmin)
# ---------------------------------------------------------------------------


def _subscription_snapshot(subscription: Subscription) -> dict:
    return {
        "plan": subscription.plan.code,
        "fecha_inicio": subscription.start_date.isoformat(),
        "fecha_fin": subscription.end_date.isoformat() if subscription.end_date else None,
        "estado": subscription.status,
        "renovacion_automatica": subscription.auto_renew,
    }


def _lock_tenant(tenant_id: int) -> Tenant:
    tenant = Tenant.objects.select_for_update().filter(pk=tenant_id).first()
    if tenant is None:
        raise NotFound("La empresa no existe.")
    return tenant


@transaction.atomic
def assign_subscription(
    *, actor, tenant_id: int, plan_id: int, months: int, auto_renew: bool, request=None
) -> Subscription:
    require_system_admin(actor)
    tenant = _lock_tenant(tenant_id)

    if get_active_subscription(tenant.id) is not None:
        raise ValidationError(
            {"suscripcion": "La empresa ya tiene una suscripción activa. Use la opción renovar."}
        )

    plan = Plan.objects.filter(pk=plan_id, active=True).first()
    if plan is None:
        raise ValidationError({"plan_id": "El plan no existe o no está activo."})

    start = today()
    subscription = Subscription.objects.create(
        tenant=tenant,
        plan=plan,
        start_date=start,
        end_date=add_months(start, months),
        status=Subscription.Status.ACTIVE,
        auto_renew=auto_renew,
    )

    record_audit(
        actor=actor,
        tenant_id=tenant.id,
        action="ASIGNAR",
        entity="suscripcion",
        entity_id=str(subscription.id),
        new_data=_subscription_snapshot(subscription),
        request=request,
    )
    return subscription


@transaction.atomic
def renew_subscription(*, actor, tenant_id: int, months: int, request=None) -> Subscription:
    require_system_admin(actor)
    tenant = _lock_tenant(tenant_id)

    active = get_active_subscription(tenant.id)

    if active is not None:
        previous = _subscription_snapshot(active)
        base_date = max(active.end_date or today(), today())
        active.end_date = add_months(base_date, months)
        active.save(update_fields=["end_date"])
        subscription = active
    else:
        last = Subscription.objects.select_related("plan").filter(tenant=tenant).order_by("-created_at").first()
        if last is None:
            raise ValidationError(
                {"suscripcion": "La empresa no tiene suscripciones previas. Use la opción asignar."}
            )
        if not last.plan.active:
            raise ValidationError(
                {"suscripcion": "El plan anterior ya no está activo. Asigne un nuevo plan."}
            )
        previous = _subscription_snapshot(last)
        start = today()
        subscription = Subscription.objects.create(
            tenant=tenant,
            plan=last.plan,
            start_date=start,
            end_date=add_months(start, months),
            status=Subscription.Status.ACTIVE,
            auto_renew=last.auto_renew,
        )

    record_audit(
        actor=actor,
        tenant_id=tenant.id,
        action="RENOVAR",
        entity="suscripcion",
        entity_id=str(subscription.id),
        previous_data=previous,
        new_data=_subscription_snapshot(subscription),
        request=request,
    )
    return subscription


@transaction.atomic
def suspend_subscription(*, actor, tenant_id: int, request=None) -> Subscription:
    require_system_admin(actor)
    tenant = _lock_tenant(tenant_id)

    active = get_active_subscription(tenant.id)
    if active is None:
        raise ValidationError({"suscripcion": "La empresa no tiene una suscripción activa para suspender."})

    previous = _subscription_snapshot(active)
    active.status = Subscription.Status.SUSPENDED
    active.save(update_fields=["status"])

    record_audit(
        actor=actor,
        tenant_id=tenant.id,
        action="SUSPENDER",
        entity="suscripcion",
        entity_id=str(active.id),
        previous_data=previous,
        new_data=_subscription_snapshot(active),
        request=request,
    )
    return active