"""
Paquetes personalizados (CU39) sobre las tablas que crea el backend de la web.

Todas las tablas ya existen en la base compartida de Railway. managed=False:
Django no crea ni modifica nada; solo lee y escribe filas.
"""

from django.conf import settings
from django.db import models


class CustomPackage(models.Model):
    class Status(models.TextChoices):
        DRAFT = "BORRADOR", "Borrador"
        SAVED = "GUARDADO", "Guardado"

    # Tabla creada por una migración de Django de la web: columnas con nombres
    # por defecto (user_id, city_id, name, ...), por eso no llevan db_column.
    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.DO_NOTHING, related_name="custom_packages")
    name = models.CharField(max_length=120)
    city = models.ForeignKey("tenancy.City", null=True, blank=True, on_delete=models.DO_NOTHING, related_name="+")
    start_date = models.DateField()
    end_date = models.DateField()
    travelers = models.PositiveSmallIntegerField()
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    total = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = "paquete_personalizado"
        ordering = ("-updated_at", "-id")


class Availability(models.Model):
    """Cupo de un producto en un periodo; en tours con ficha es una salida con hora."""

    id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(
        "catalogo.Product", db_column="id_producto", on_delete=models.DO_NOTHING, related_name="+"
    )
    start = models.DateTimeField(db_column="inicio")
    end = models.DateTimeField(db_column="fin")
    total_capacity = models.PositiveIntegerField(db_column="cupo_total")
    closed = models.BooleanField(db_column="cerrado", default=False)

    class Meta:
        managed = False
        db_table = "disponibilidad"


class Room(models.Model):
    """Tipo de habitación: cuántas unidades tiene el hospedaje. El precio por noche es el del producto."""

    id = models.BigAutoField(primary_key=True)
    product = models.OneToOneField(
        "catalogo.Product", db_column="id_producto", on_delete=models.DO_NOTHING, related_name="room"
    )
    quantity = models.PositiveIntegerField(db_column="cantidad_habitaciones", default=1)

    class Meta:
        managed = False
        db_table = "habitacion"


class TourDetail(models.Model):
    """Si un tour tiene ficha, solo se vende por salidas programadas."""

    id = models.BigAutoField(primary_key=True)
    product = models.OneToOneField(
        "catalogo.Product", db_column="id_producto", on_delete=models.DO_NOTHING, related_name="tour"
    )

    class Meta:
        managed = False
        db_table = "detalle_tour"


class PackageComponent(models.Model):
    id = models.BigAutoField(primary_key=True)
    package = models.ForeignKey(CustomPackage, on_delete=models.CASCADE, related_name="components")
    product = models.ForeignKey("catalogo.Product", on_delete=models.DO_NOTHING, related_name="+")
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    quantity = models.PositiveSmallIntegerField()
    guests = models.PositiveSmallIntegerField(null=True, blank=True)
    departure = models.ForeignKey(Availability, null=True, blank=True, on_delete=models.DO_NOTHING, related_name="+")
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    total = models.DecimalField(max_digits=14, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "paquete_personalizado_componente"
        ordering = ("start_date", "id")


class PackagePurchase(models.Model):
    """Compra hecha desde la web (con pago). La app solo la consulta."""

    class Status(models.TextChoices):
        CREATED = "CREADA", "Pendiente de pago"
        CONFIRMED = "CONFIRMADA", "Confirmada"
        CANCELLED = "CANCELADA", "Cancelada"
        EXPIRED = "EXPIRADA", "Expirada"
        REFUNDED = "REEMBOLSADA", "Reembolsada"

    id = models.BigAutoField(primary_key=True)
    package = models.OneToOneField(CustomPackage, on_delete=models.DO_NOTHING, related_name="purchase")
    status = models.CharField(max_length=20, choices=Status.choices)
    final_amount = models.DecimalField(max_digits=14, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "compra_paquete_personalizado"