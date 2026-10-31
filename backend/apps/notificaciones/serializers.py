from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    """Mismo formato que usa la web, para que ambas apps lean igual el aviso."""

    tipo = serializers.CharField(source="kind")
    titulo = serializers.CharField(source="title")
    mensaje = serializers.CharField(source="message")
    datos = serializers.JSONField(source="data")
    leida = serializers.SerializerMethodField()
    es_recordatorio = serializers.BooleanField(source="is_reminder")
    creado_en = serializers.DateTimeField(source="created_at")

    class Meta:
        model = Notification
        fields = ("id", "tipo", "titulo", "mensaje", "datos", "leida", "es_recordatorio", "creado_en")

    def get_leida(self, notification) -> bool:
        return notification.read_at is not None


class UnreadSerializer(serializers.Serializer):
    no_leidas = serializers.IntegerField()
    recordatorios_no_leidos = serializers.IntegerField()