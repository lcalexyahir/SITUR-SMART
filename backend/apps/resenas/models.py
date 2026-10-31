from django.conf import settings
from django.db import models


class ProductReview(models.Model):
    """
    Calificación (1 a 5) y comentario de un turista sobre un producto (CU35).

    La tabla resena_producto ya existe en la base compartida de Railway
    (la crea el script 020_resenas_producto.sql). managed=False: Django no
    crea ni modifica la tabla, solo la lee y escribe filas.
    """

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        db_column="id_usuario",
        on_delete=models.DO_NOTHING,
        related_name="product_reviews",
    )
    product = models.ForeignKey(
        "catalogo.Product",
        db_column="id_producto",
        on_delete=models.DO_NOTHING,
        related_name="reviews",
    )
    rating = models.SmallIntegerField(db_column="calificacion")
    comment = models.TextField(db_column="comentario")
    created_at = models.DateTimeField(db_column="creado_en", auto_now_add=True)
    updated_at = models.DateTimeField(db_column="actualizado_en", auto_now=True)

    class Meta:
        managed = False
        db_table = "resena_producto"
        ordering = ("-created_at", "-id")

    def __str__(self) -> str:
        return f"{self.rating}★ de {self.user_id} sobre {self.product_id}"