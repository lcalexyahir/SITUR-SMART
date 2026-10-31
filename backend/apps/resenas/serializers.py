from rest_framework import serializers

from .models import ProductReview

MIN_COMMENT = 3
MAX_COMMENT = 1000


class ReviewInputSerializer(serializers.Serializer):
    """Datos que envía la app al crear o editar una reseña."""

    calificacion = serializers.IntegerField(
        min_value=1,
        max_value=5,
        error_messages={
            "min_value": "La calificación debe estar entre 1 y 5 estrellas.",
            "max_value": "La calificación debe estar entre 1 y 5 estrellas.",
            "required": "Elige una calificación de 1 a 5 estrellas.",
        },
    )
    comentario = serializers.CharField(
        trim_whitespace=True,
        min_length=MIN_COMMENT,
        max_length=MAX_COMMENT,
        error_messages={
            "min_length": f"El comentario debe tener al menos {MIN_COMMENT} caracteres.",
            "max_length": f"El comentario no puede superar los {MAX_COMMENT} caracteres.",
            "blank": "Escribe un comentario sobre tu experiencia.",
            "required": "Escribe un comentario sobre tu experiencia.",
        },
    )


class ReviewSerializer(serializers.ModelSerializer):
    """Reseña tal como se muestra en la ficha del producto."""

    calificacion = serializers.IntegerField(source="rating")
    comentario = serializers.CharField(source="comment")
    autor = serializers.SerializerMethodField()
    es_mia = serializers.SerializerMethodField()
    editada = serializers.SerializerMethodField()
    creado_en = serializers.DateTimeField(source="created_at")
    actualizado_en = serializers.DateTimeField(source="updated_at")

    class Meta:
        model = ProductReview
        fields = ("id", "calificacion", "comentario", "autor", "es_mia", "editada", "creado_en", "actualizado_en")

    def get_autor(self, review) -> str:
        # Solo nombre e inicial del apellido: no se expone el correo del turista.
        first = (review.user.first_names or "").strip().split(" ")[0]
        last = (review.user.last_names or "").strip()
        if not first:
            return "Viajero"
        return f"{first} {last[0]}." if last else first

    def get_es_mia(self, review) -> bool:
        request = self.context.get("request")
        return bool(request and request.user and review.user_id == request.user.id)

    def get_editada(self, review) -> bool:
        if review.created_at is None or review.updated_at is None:
            return False
        return (review.updated_at - review.created_at).total_seconds() > 60


class MyReviewSerializer(ReviewSerializer):
    """Reseña propia con los datos del producto, para "Mis reseñas"."""

    producto = serializers.SerializerMethodField()

    class Meta(ReviewSerializer.Meta):
        fields = (*ReviewSerializer.Meta.fields, "producto")

    def get_producto(self, review) -> dict:
        product = review.product
        return {
            "id": product.id,
            "nombre": product.name,
            "imagen_url": product.image_url,
            "tipo": product.product_type.name,
            "disponible": product.status == product.Status.PUBLISHED,
        }


class SummarySerializer(serializers.Serializer):
    promedio = serializers.FloatField(allow_null=True)
    total = serializers.IntegerField()
    distribucion = serializers.DictField(child=serializers.IntegerField())