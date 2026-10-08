from rest_framework_simplejwt.authentication import JWTAuthentication

from .services import ensure_tenant_access


def _tenant_id_from_header(request) -> int | None:
    raw = request.headers.get("X-Tenant-ID")
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError:
        # El formato invalido lo rechaza la vista correspondiente.
        return None


class SubscriptionJWTAuthentication(JWTAuthentication):
    """
    Autenticacion JWT que, despues de validar el token, verifica que la
    empresa del usuario este habilitada y con suscripcion vigente
    (modelo SaaS). Ver ensure_tenant_access.

    Tambien deja el usuario en la peticion de Django (audit_user) para que
    la bitacora confidencial sepa quien hizo cada accion.
    """

    def authenticate(self, request):
        result = super().authenticate(request)
        if result is None:
            return None
        user, token = result
        request._request.audit_user = user
        ensure_tenant_access(user, _tenant_id_from_header(request), request.method)
        return user, token