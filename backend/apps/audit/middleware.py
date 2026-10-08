import re
from uuid import uuid4

from . import secure_log


class RequestIdMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.request_id = request.headers.get("X-Request-ID") or str(uuid4())
        response = self.get_response(request)
        response["X-Request-ID"] = request.request_id
        return response


# ---------------------------------------------------------------------------
# Bitácora confidencial: registra cada acción de un usuario autenticado.
# ---------------------------------------------------------------------------

# Rutas que no son acciones de usuario.
IGNORED_PREFIXES = (
    "/api/v1/health/",
    "/api/schema/",
    "/api/docs/",
    "/static/",
    "/favicon",
)

VERBS = {
    "GET": "Consultó",
    "POST": "Registró",
    "PUT": "Modificó",
    "PATCH": "Modificó",
    "DELETE": "Eliminó",
}

# Acciones con descripción propia: (método, patrón de ruta, descripción).
# {id} se reemplaza por el número que aparece en la ruta.
SPECIFIC_ACTIONS = (
    ("POST", r"^/api/v1/tenants/(\d+)/suscripcion/asignar/$", "Asignó un plan a la empresa #{id}"),
    ("POST", r"^/api/v1/tenants/(\d+)/suscripcion/renovar/$", "Renovó la suscripción de la empresa #{id}"),
    ("POST", r"^/api/v1/tenants/(\d+)/suscripcion/suspender/$", "Suspendió la suscripción de la empresa #{id}"),
    ("GET", r"^/api/v1/tenants/(\d+)/suscripcion/$", "Consultó la suscripción de la empresa #{id}"),
    ("POST", r"^/api/v1/tenants/(\d+)/estado/$", "Cambió el estado operativo de la empresa #{id}"),
    ("GET", r"^/api/v1/tenants/(\d+)/$", "Consultó la empresa #{id}"),
    ("PUT", r"^/api/v1/tenants/(\d+)/$", "Modificó los datos de la empresa #{id}"),
    ("PATCH", r"^/api/v1/tenants/(\d+)/$", "Modificó los datos de la empresa #{id}"),
    ("GET", r"^/api/v1/tenants/$", "Consultó la lista de empresas"),
    ("POST", r"^/api/v1/tenants/$", "Registró una nueva empresa"),
    ("GET", r"^/api/v1/planes/$", "Consultó los planes de suscripción"),
    ("GET", r"^/api/v1/auth/me/$", "Ingresó a la aplicación"),
    ("GET", r"^/api/v1/auth/perfil/$", "Consultó su perfil"),
    ("PUT", r"^/api/v1/auth/perfil/$", "Actualizó su perfil"),
    ("POST", r"^/api/v1/auth/cambiar-password/$", "Cambió su contraseña"),
    ("GET", r"^/api/v1/auth/users/$", "Consultó la lista de usuarios"),
    ("POST", r"^/api/v1/auth/users/$", "Registró un nuevo usuario"),
    ("GET", r"^/api/v1/auth/users/(\d+)/$", "Consultó el usuario #{id}"),
    ("PUT", r"^/api/v1/auth/users/(\d+)/$", "Modificó el usuario #{id}"),
    ("PATCH", r"^/api/v1/auth/users/(\d+)/$", "Modificó el usuario #{id}"),
    ("DELETE", r"^/api/v1/auth/users/(\d+)/$", "Eliminó el usuario #{id}"),
    ("GET", r"^/api/v1/roles/$", "Consultó los roles"),
    ("POST", r"^/api/v1/roles/$", "Registró un nuevo rol"),
    ("GET", r"^/api/v1/permissions/$", "Consultó los permisos"),
    ("GET", r"^/api/v1/catalogo/productos/$", "Exploró el catálogo turístico"),
    ("GET", r"^/api/v1/catalogo/productos/(\d+)/$", "Consultó el producto turístico #{id}"),
    ("GET", r"^/api/v1/catalogo/tipos/$", "Consultó los tipos de experiencia"),
    ("POST", r"^/api/v1/audit/log-seguro/$", "Consultó la bitácora confidencial"),
)

RESOURCE_NAMES = {
    "tenants": "empresas",
    "planes": "planes",
    "auth": "su cuenta",
    "roles": "roles",
    "permissions": "permisos",
    "catalogo": "el catálogo",
    "audit": "la bitácora",
}

_COMPILED = [(method, re.compile(pattern), text) for method, pattern, text in SPECIFIC_ACTIONS]


def describe(method: str, path: str) -> str:
    for action_method, pattern, text in _COMPILED:
        if action_method == method:
            match = pattern.match(path)
            if match:
                return text.format(id=match.group(1) if match.groups() else "")

    verb = VERBS.get(method, method)
    if path.startswith("/admin/"):
        return f"{verb} en el panel de administración: {path}"

    parts = [part for part in path.split("/") if part]
    if len(parts) >= 3 and parts[0] == "api":
        resource = RESOURCE_NAMES.get(parts[2], parts[2])
        return f"{verb} {resource} ({path})"
    return f"{verb} {path}"


class SecureAuditMiddleware:
    """
    Escribe en la bitácora confidencial cada petición hecha por un usuario
    autenticado: IP, usuario, fecha, hora (Bolivia) y acción.

    El usuario de la API llega por JWT y lo deja la clase de autenticación
    en request.audit_user. El del panel /admin/ llega por sesión de Django.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        if request.method in ("OPTIONS", "HEAD") or request.path.startswith(IGNORED_PREFIXES):
            return response

        user = getattr(request, "audit_user", None)
        if user is None:
            session_user = getattr(request, "user", None)
            if session_user is not None and session_user.is_authenticated:
                user = session_user

        if user is None:
            return response

        action = describe(request.method, request.path)
        if response.status_code >= 400:
            action = f"{action} (rechazado, código {response.status_code})"

        secure_log.write(request=request, user=user, action=action, status=response.status_code)
        return response