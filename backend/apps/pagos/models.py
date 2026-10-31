"""
Historial de pagos del turista (solo lectura).

Las reservas y los pagos los crea la web con su pasarela (Stripe). La app
móvil solo los consulta. Todas las tablas existen en la base compartida de
Railway; managed=False: Django no modifica nada.
"""

from django.db import models


class Order(models.Model):
    id = models.BigAutoField(primary_key=True)
    customer = models.ForeignKey(
        "accounts.ClientProfile", db_column="id_cliente", on_delete=models.DO_NOTHING, related_name="+"
    )
    code = models.CharField(db_column="codigo", max_length=60)
    status = models.CharField(db_column="estado", max_length=25)

    class Meta:
        managed = False
        db_table = "orden_reserva"


class Booking(models.Model):
    id = models.BigAutoField(primary_key=True)
    order = models.ForeignKey(Order, db_column="id_orden", on_delete=models.DO_NOTHING, related_name="bookings")
    tenant = models.ForeignKey("tenancy.Tenant", db_column="id_tenant", on_delete=models.DO_NOTHING, related_name="+")
    code = models.CharField(db_column="codigo_reserva", max_length=60)
    status = models.CharField(db_column="estado", max_length=25)

    class Meta:
        managed = False
        db_table = "reserva"


class BookingDetail(models.Model):
    id = models.BigAutoField(primary_key=True)
    booking = models.ForeignKey(Booking, db_column="id_reserva", on_delete=models.DO_NOTHING, related_name="details")
    slot = models.ForeignKey(
        "paquetes.Availability", db_column="id_disponibilidad", on_delete=models.DO_NOTHING, related_name="+"
    )

    class Meta:
        managed = False
        db_table = "reserva_detalle"


class Payment(models.Model):
    class State(models.TextChoices):
        PENDING = "PENDIENTE", "Pendiente"
        APPROVED = "APROBADO", "Aprobado"
        REJECTED = "RECHAZADO", "Rechazado"
        VOIDED = "ANULADO", "Anulado"

    id = models.BigAutoField(primary_key=True)
    booking = models.ForeignKey(Booking, db_column="id_reserva", on_delete=models.DO_NOTHING, related_name="payments")
    currency = models.ForeignKey("tenancy.Currency", db_column="id_moneda", on_delete=models.DO_NOTHING, related_name="+")
    amount = models.DecimalField(db_column="monto", max_digits=12, decimal_places=2)
    method = models.CharField(db_column="metodo", max_length=30)
    status = models.CharField(db_column="estado", max_length=20)
    provider = models.CharField(db_column="proveedor", max_length=60)
    created_at = models.DateTimeField(db_column="creado_en")
    processed_at = models.DateTimeField(db_column="procesado_en", null=True)

    class Meta:
        managed = False
        db_table = "pago"
        ordering = ("-created_at", "-id")


class Refund(models.Model):
    id = models.BigAutoField(primary_key=True)
    payment = models.ForeignKey(Payment, db_column="id_pago", on_delete=models.DO_NOTHING, related_name="refunds")
    amount = models.DecimalField(db_column="monto", max_digits=12, decimal_places=2)
    status = models.CharField(db_column="estado", max_length=20)
    reason = models.TextField(db_column="motivo", null=True)
    requested_at = models.DateTimeField(db_column="solicitado_en")
    processed_at = models.DateTimeField(db_column="procesado_en", null=True)

    class Meta:
        managed = False
        db_table = "reembolso"
        ordering = ("-requested_at", "-id")