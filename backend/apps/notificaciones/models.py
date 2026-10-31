from django.conf import settings
from django.db import models


class Notification(models.Model):
    """
    Aviso para el usuario dentro de la app (CU45).

    La tabla notificacion ya existe en la base compartida de Railway (script
    011_notificaciones.sql). La web y su backend escriben aquí las
    confirmaciones de reserva y los recordatorios previos; la app móvil lee
    los mismos registros. managed=False: Django no toca la estructura.
    """

    class Kind(models.TextChoices):
        BOOKING_CONFIRMED = "RESERVA_CONFIRMADA", "Reserva confirmada"
        BOOKING_EXPIRED = "RESERVA_VENCIDA", "Reserva vencida"
        BOOKING_CANCELLED = "RESERVA_CANCELADA", "Reserva cancelada"
        PAYMENT_ISSUE = "PAGO_REVISION", "Pago en revisión"
        REFUND_COMPLETED = "REEMBOLSO_COMPLETADO", "Reembolso completado"
        REFUND_FAILED = "REEMBOLSO_FALLIDO", "Reembolso fallido"
        BOOKING_REMINDER_24H = "RECORDATORIO_24H", "Recordatorio 24 horas antes"
        BOOKING_REMINDER_2H = "RECORDATORIO_2H", "Recordatorio 2 horas antes"

    # Todo tipo que empiece así se muestra en la pestaña "Recordatorios".
    REMINDER_PREFIX = "RECORDATORIO"

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        db_column="id_usuario",
        on_delete=models.DO_NOTHING,
        related_name="notifications",
    )
    kind = models.CharField(db_column="tipo", max_length=40)
    title = models.CharField(db_column="titulo", max_length=150)
    message = models.TextField(db_column="mensaje")
    data = models.JSONField(db_column="datos", default=dict)
    read_at = models.DateTimeField(db_column="leida_en", null=True, blank=True)
    created_at = models.DateTimeField(db_column="creado_en", auto_now_add=True)

    class Meta:
        managed = False
        db_table = "notificacion"
        ordering = ("-created_at", "-id")

    def __str__(self) -> str:
        return f"{self.kind} para {self.user_id}: {self.title}"

    @property
    def is_reminder(self) -> bool:
        return self.kind.startswith(self.REMINDER_PREFIX)