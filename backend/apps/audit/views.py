from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status
from rest_framework.exceptions import APIException, PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import secure_log


class SecureLogNotAvailable(APIException):
    """La bitácora confidencial no tiene sus llaves configuradas (HTTP 503)."""

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    default_detail = "La bitácora confidencial no está configurada en el servidor."
    default_code = "bitacora_no_configurada"


class SecureLogQuerySerializer(serializers.Serializer):
    llave = serializers.CharField(trim_whitespace=False)
    desde = serializers.DateField(required=False, allow_null=True)
    hasta = serializers.DateField(required=False, allow_null=True)
    usuario = serializers.CharField(required=False, allow_blank=True, default="")
    accion = serializers.CharField(required=False, allow_blank=True, default="")
    ip = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, attrs):
        desde, hasta = attrs.get("desde"), attrs.get("hasta")
        if desde and hasta and desde > hasta:
            raise serializers.ValidationError({"desde": "La fecha 'desde' no puede ser posterior a 'hasta'."})
        return attrs


class SecureLogView(APIView):
    """
    Consulta de la bitácora confidencial. Solo responde si se presenta la
    llave única del desarrollador; cada intento queda registrado.
    """

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=SecureLogQuerySerializer, responses={200: None})
    def post(self, request):
        if not secure_log.is_configured():
            raise SecureLogNotAvailable()

        serializer = SecureLogQuerySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if not secure_log.verify_developer_key(data["llave"]):
            # El intento queda registrado por SecureAuditMiddleware (código 403).
            raise PermissionDenied("La llave del desarrollador no es válida.")

        registros, total = secure_log.read(
            date_from=data.get("desde"),
            date_to=data.get("hasta"),
            user_text=data["usuario"],
            action_text=data["accion"],
            ip_text=data["ip"],
        )
        return Response(
            {
                "zona_horaria": "America/La_Paz (UTC-04:00)",
                "total": total,
                "mostrando": len(registros),
                "registros": registros,
            }
        )