"""Reglas del CU35: calificaciones y reseñas de productos turísticos."""

from django.db import IntegrityError, transaction
from django.db.models import Avg, Count
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

from apps.accounts.models import ClientProfile
from apps.catalogo.models import Product
from apps.catalogo.views import published_products

from .models import ProductReview

DUPLICATE_MESSAGE = "Ya registraste una reseña para este producto. Puedes editarla."


def is_client(user) -> bool:
    """Solo los turistas (con perfil de cliente) califican productos."""
    return ClientProfile.objects.filter(user_id=user.id).exists()


def visible_product(product_id: int) -> Product:
    """Mismo criterio que la ficha del producto: publicado y empresa operativa."""
    product = published_products().filter(pk=product_id).first()
    if product is None:
        raise NotFound("El producto no existe o no está disponible.")
    return product


def product_reviews(product: Product):
    return ProductReview.objects.select_related("user").filter(product=product).order_by("-created_at", "-id")


def summary(product: Product) -> dict:
    """Promedio, total y cuántas reseñas tiene cada cantidad de estrellas."""
    reviews = ProductReview.objects.filter(product=product)
    totals = reviews.order_by().aggregate(promedio=Avg("rating"), total=Count("id"))
    distribution = {str(stars): 0 for stars in range(1, 6)}
    for row in reviews.order_by().values("rating").annotate(cantidad=Count("id")):
        distribution[str(row["rating"])] = row["cantidad"]

    average = totals["promedio"]
    return {
        "promedio": round(float(average), 1) if average is not None else None,
        "total": totals["total"] or 0,
        "distribucion": distribution,
    }


def own_review_for_product(*, user, product: Product) -> ProductReview | None:
    return ProductReview.objects.select_related("user").filter(user_id=user.id, product=product).first()


def own_review(*, user, review_id: int) -> ProductReview:
    review = (
        ProductReview.objects.select_related("user", "product__product_type")
        .filter(id=review_id, user_id=user.id)
        .first()
    )
    if review is None:
        raise NotFound("Reseña no encontrada.")
    return review


def my_reviews(*, user):
    return (
        ProductReview.objects.select_related("user", "product__product_type")
        .filter(user_id=user.id)
        .order_by("-created_at", "-id")
    )


def create_review(*, user, product_id: int, rating: int, comment: str) -> ProductReview:
    if not is_client(user):
        raise PermissionDenied("Solo los turistas pueden calificar productos.")

    product = visible_product(product_id)
    if ProductReview.objects.filter(user_id=user.id, product=product).exists():
        raise ValidationError({"detail": DUPLICATE_MESSAGE})

    try:
        with transaction.atomic():
            review = ProductReview.objects.create(user=user, product=product, rating=rating, comment=comment)
    except IntegrityError as exc:
        # La restricción UNIQUE (usuario, producto) de la tabla también
        # protege dos envíos simultáneos desde la web y el móvil.
        raise ValidationError({"detail": DUPLICATE_MESSAGE}) from exc
    return review


def update_review(*, user, review_id: int, rating: int, comment: str) -> ProductReview:
    review = own_review(user=user, review_id=review_id)
    review.rating = rating
    review.comment = comment
    review.save(update_fields=["rating", "comment", "updated_at"])
    return review


def delete_review(*, user, review_id: int) -> None:
    own_review(user=user, review_id=review_id).delete()