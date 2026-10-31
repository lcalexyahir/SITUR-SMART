from django.conf import settings
from django.db import models


class Itinerary(models.Model):
    """
    Plan de un viaje del turista: un rango de días con actividades.

    Tablas itinerario e itinerario_actividad de la base compartida de
    Railway (las crea el backend de la web). managed=False.
    """

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        db_column="id_usuario",
        on_delete=models.DO_NOTHING,
        related_name="itineraries",
    )
    name = models.CharField(db_column="nombre", max_length=120)
    city = models.ForeignKey(
        "tenancy.City",
        db_column="id_ciudad",
        on_delete=models.DO_NOTHING,
        null=True,
        related_name="+",
    )
    start_date = models.DateField(db_column="fecha_inicio")
    end_date = models.DateField(db_column="fecha_fin")
    notes = models.TextField(db_column="notas", null=True)
    created_at = models.DateTimeField(db_column="creado_en", auto_now_add=True)
    updated_at = models.DateTimeField(db_column="actualizado_en", auto_now=True)

    class Meta:
        managed = False
        db_table = "itinerario"
        ordering = ("-start_date", "-id")


class ItineraryActivity(models.Model):
    """Algo que hacer un día del viaje: un producto del catálogo o algo libre."""

    id = models.BigAutoField(primary_key=True)
    itinerary = models.ForeignKey(
        Itinerary,
        db_column="id_itinerario",
        # Al borrar un itinerario desde la app se borran también sus actividades.
        on_delete=models.CASCADE,
        related_name="activities",
    )
    date = models.DateField(db_column="fecha")
    time = models.TimeField(db_column="hora", null=True)
    product = models.ForeignKey(
        "catalogo.Product",
        db_column="id_producto",
        on_delete=models.DO_NOTHING,
        null=True,
        related_name="+",
    )
    title = models.CharField(db_column="titulo", max_length=150)
    note = models.TextField(db_column="nota", null=True)
    created_at = models.DateTimeField(db_column="creado_en", auto_now_add=True)

    class Meta:
        managed = False
        db_table = "itinerario_actividad"
        ordering = ("date", "time", "id")