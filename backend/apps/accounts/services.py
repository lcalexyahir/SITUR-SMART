from datetime import UTC, datetime
from hashlib import sha256

from django.contrib.auth import authenticate
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed

from rest_framework_simplejwt.tokens import RefreshToken

from apps.audit import secure_log
from apps.audit.services import record_audit
from apps.rbac.models import Role, UserRole
from apps.tenancy.services import ensure_tenant_access

from .models import ClientProfile, User, UserSession

# Si en la base existe un rol global para clientes, se asigna al registrarse.
# Se prueba en este orden; si no existe ninguno, el cliente se identifica por
# su registro en perfil_cliente.
CLIENT_ROLE_CODES = ("VIAJERO", "TURISTA", "CLIENTE")


def token_hash(token: str) -> str:
    return sha256(token.encode("utf-8")).hexdigest()


def request_ip(request) -> str | None:
    return secure_log.client_ip(request)


def token_pair_for_user(user: User, request) -> dict[str, str]:
    refresh = RefreshToken.for_user(user)
    refresh["email"] = user.email
    raw_refresh = str(refresh)
    expires_at = datetime.fromtimestamp(int(refresh["exp"]), tz=UTC)
    UserSession.objects.create(
        user=user,
        refresh_token_hash=token_hash(raw_refresh),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:1000],
        ip=request_ip(request),
        expires_at=expires_at,
    )
    return {"access": str(refresh.access_token), "refresh": raw_refresh}


@transaction.atomic
def login_user(*, email: str, password: str, request) -> tuple[User, dict[str, str]]:
    user = authenticate(request=request, username=email, password=password)
    if user is None:
        secure_log.write(request=request, action="Intento de inicio de sesión fallido", email=email, status=401)
        raise AuthenticationFailed("Credenciales incorrectas.")
    if not user.is_active:
        secure_log.write(
            request=request, user=user, action="Intento de inicio de sesión con cuenta inactiva", status=401
        )
        raise AuthenticationFailed("La cuenta no se encuentra activa.")
    # Modelo SaaS: la empresa debe estar habilitada y con suscripcion vigente.
    try:
        ensure_tenant_access(user)
    except Exception:
        secure_log.write(
            request=request, user=user, action="Inicio de sesión bloqueado (empresa o suscripción no vigente)"
        )
        raise
    user.last_login = timezone.now()
    user.save(update_fields=["last_login"])
    secure_log.write(request=request, user=user, action="Inició sesión", status=200)
    return user, token_pair_for_user(user, request)


@transaction.atomic
def rotate_refresh_token(*, raw_refresh: str, request) -> tuple[User, dict[str, str]]:
    try:
        refresh = RefreshToken(raw_refresh)
        user_id = int(refresh["user_id"])
    except Exception as exc:
        raise AuthenticationFailed("Refresh token inválido.") from exc

    session = UserSession.objects.select_for_update().filter(
        refresh_token_hash=token_hash(raw_refresh),
        revoked_at__isnull=True,
        expires_at__gt=timezone.now(),
    ).first()
    if session is None or session.user_id != user_id:
        raise AuthenticationFailed("La sesión ya no está activa.")

    user = User.objects.get(pk=user_id)
    if not user.is_active:
        raise AuthenticationFailed("La cuenta no se encuentra activa.")
    # Modelo SaaS: no se renueva la sesion si la suscripcion ya no esta vigente.
    ensure_tenant_access(user)

    session.revoked_at = timezone.now()
    session.save(update_fields=["revoked_at"])
    return user, token_pair_for_user(user, request)


def revoke_refresh_token(raw_refresh: str, request=None) -> None:
    session = (
        UserSession.objects.select_related("user")
        .filter(refresh_token_hash=token_hash(raw_refresh), revoked_at__isnull=True)
        .first()
    )
    if session is None:
        return
    session.revoked_at = timezone.now()
    session.save(update_fields=["revoked_at"])
    secure_log.write(request=request, user=session.user, action="Cerró sesión", status=204)


# ---------------------------------------------------------------------------
# Clientes (viajeros)
# ---------------------------------------------------------------------------


def _client_role() -> Role | None:
    roles = {
        role.code: role
        for role in Role.objects.filter(code__in=CLIENT_ROLE_CODES, scope=Role.Scope.GLOBAL, tenant__isnull=True)
    }
    for code in CLIENT_ROLE_CODES:
        if code in roles:
            return roles[code]
    return None


@transaction.atomic
def register_client(*, data: dict, request) -> tuple[User, dict[str, str]]:
    """Crea la cuenta del viajero, su perfil de cliente e inicia su sesion."""
    user = User.objects.create_user(
        email=data["email"],
        password=data["password"],
        first_names=data["nombres"],
        last_names=data["apellidos"],
        phone=data.get("telefono"),
        status=User.Status.ACTIVE,
    )
    ClientProfile.objects.create(
        user=user,
        document_type=data.get("tipo_documento"),
        document_number=data.get("numero_documento"),
        preferences={},
    )

    role = _client_role()
    if role is not None:
        UserRole.objects.create(user=user, role=role, tenant=None)

    record_audit(
        actor=user,
        action="REGISTRO",
        entity="usuario",
        entity_id=str(user.id),
        new_data={"email": user.email, "nombres": user.first_names, "apellidos": user.last_names},
        request=request,
    )

    user.last_login = timezone.now()
    user.save(update_fields=["last_login"])
    secure_log.write(request=request, user=user, action="Se registró como cliente (viajero)", status=201)
    return user, token_pair_for_user(user, request)


def profile_data(user: User) -> dict:
    profile = ClientProfile.objects.filter(user=user).first()
    return {
        "id": user.id,
        "email": user.email,
        "nombres": user.first_names,
        "apellidos": user.last_names,
        "telefono": user.phone,
        "es_cliente": profile is not None,
        "tipo_documento": profile.document_type if profile else None,
        "numero_documento": profile.document_number if profile else None,
        "fecha_nacimiento": profile.birth_date if profile else None,
    }


@transaction.atomic
def update_profile(*, user: User, data: dict, request) -> dict:
    previous = profile_data(user)

    user.first_names = data["nombres"]
    user.last_names = data["apellidos"]
    user.phone = data.get("telefono")
    user.save(update_fields=["first_names", "last_names", "phone"])

    profile = ClientProfile.objects.filter(user=user).first()
    if profile is not None:
        profile.document_type = data.get("tipo_documento")
        profile.document_number = data.get("numero_documento")
        profile.birth_date = data.get("fecha_nacimiento")
        profile.save(update_fields=["document_type", "document_number", "birth_date"])

    current = profile_data(user)
    record_audit(
        actor=user,
        action="EDITAR_PERFIL",
        entity="usuario",
        entity_id=str(user.id),
        previous_data={key: str(value) if value is not None else None for key, value in previous.items()},
        new_data={key: str(value) if value is not None else None for key, value in current.items()},
        request=request,
    )
    return current


@transaction.atomic
def change_password(*, user: User, new_password: str, request) -> None:
    user.set_password(new_password)
    user.save(update_fields=["password"])
    record_audit(
        actor=user,
        action="CAMBIAR_PASSWORD",
        entity="usuario",
        entity_id=str(user.id),
        request=request,
    )