import os

from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403

DEBUG = False

# ---------------------------------------------------------------------------
# Secretos: en produccion la clave debe venir de las variables de Railway.
# ---------------------------------------------------------------------------
if not os.getenv("DJANGO_SECRET_KEY") or SECRET_KEY == "unsafe-development-key-change-me":  # noqa: F405
    raise ImproperlyConfigured("Defina DJANGO_SECRET_KEY en las variables de entorno de producción.")

# ---------------------------------------------------------------------------
# Hosts: dominio publico de Railway + dominios definidos manualmente.
# Railway expone RAILWAY_PUBLIC_DOMAIN (ej. situr-mobile.up.railway.app).
# El healthcheck de Railway llega con el host healthcheck.railway.app.
# ---------------------------------------------------------------------------
_railway_domain = os.getenv("RAILWAY_PUBLIC_DOMAIN")
if _railway_domain and _railway_domain not in ALLOWED_HOSTS:  # noqa: F405
    ALLOWED_HOSTS.append(_railway_domain)  # noqa: F405
if "healthcheck.railway.app" not in ALLOWED_HOSTS:  # noqa: F405
    ALLOWED_HOSTS.append("healthcheck.railway.app")  # noqa: F405

CSRF_TRUSTED_ORIGINS = [
    f"https://{host}"
    for host in ALLOWED_HOSTS  # noqa: F405
    if host not in {"localhost", "127.0.0.1", "healthcheck.railway.app"}
]

# ---------------------------------------------------------------------------
# HTTPS: Railway termina TLS en su proxy y reenvia X-Forwarded-Proto.
# ---------------------------------------------------------------------------
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = True
# El healthcheck interno de Railway usa HTTP; no se redirige.
SECURE_REDIRECT_EXEMPT = [r"^api/v1/health/$"]
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = int(os.getenv("SECURE_HSTS_SECONDS", "2592000"))
SECURE_HSTS_INCLUDE_SUBDOMAINS = False
SECURE_CONTENT_TYPE_NOSNIFF = True

# La API publica se consume desde los clientes. Limitarla a JSON evita que DRF
# intente renderizar su interfaz HTML en produccion.
REST_FRAMEWORK["DEFAULT_RENDERER_CLASSES"] = [  # noqa: F405
    "rest_framework.renderers.JSONRenderer",
]

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

# ---------------------------------------------------------------------------
# Logs a la salida estandar para verlos en el panel de Railway.
# ---------------------------------------------------------------------------
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": os.getenv("DJANGO_LOG_LEVEL", "INFO")},
}