from rest_framework.exceptions import APIException


class _CodedAPIException(APIException):
    """
    Excepcion que envia un codigo legible por la app movil dentro de
    error.details.code, ademas del mensaje.
    """

    error_code = "error"

    def __init__(self, detail=None):
        message = detail or self.default_detail
        super().__init__({"detail": message, "code": self.error_code})


class SubscriptionInactive(_CodedAPIException):
    """La empresa no tiene una suscripcion vigente (HTTP 402)."""

    status_code = 402
    default_detail = (
        "La suscripción de la empresa no está vigente. "
        "Contacte al administrador del sistema para renovarla."
    )
    default_code = "suscripcion_inactiva"
    error_code = "suscripcion_inactiva"


class TenantNotOperational(_CodedAPIException):
    """La empresa esta pendiente de activacion o inactiva (HTTP 403)."""

    status_code = 403
    default_detail = (
        "Su empresa no está habilitada para operar en SITUR-SMART. "
        "Contacte al administrador del sistema."
    )
    default_code = "empresa_no_habilitada"
    error_code = "empresa_no_habilitada"


class TenantReadOnly(_CodedAPIException):
    """La empresa esta suspendida temporalmente: solo lectura (HTTP 403)."""

    status_code = 403
    default_detail = (
        "La empresa está suspendida temporalmente: puede consultar información, "
        "pero no registrar cambios."
    )
    default_code = "empresa_suspendida"
    error_code = "empresa_suspendida"