"""Favoritos del turista: misma tabla y mismas reglas que la web."""

from rest_framework.exceptions import NotFound

from apps.catalogo.views import published_products

from .models import Favorite


def list_favorites(*, user):
    """
    Productos favoritos visibles, del más reciente al más antiguo.

    Un favorito cuyo producto dejó de publicarse no se borra: si la empresa
    lo vuelve a publicar, reaparece. Mientras tanto solo se oculta.
    """
    ids = list(Favorite.objects.filter(user_id=user.id).values_list("product_id", flat=True))
    products = {product.id: product for product in published_products().filter(id__in=ids)}
    return [products[product_id] for product_id in ids if product_id in products]


def favorite_ids(*, user) -> list[int]:
    return list(Favorite.objects.filter(user_id=user.id).values_list("product_id", flat=True))


def add_favorite(*, user, product_id: int) -> bool:
    """Marca un producto. Devuelve True si se creó y False si ya estaba."""
    if not published_products().filter(id=product_id).exists():
        raise NotFound("El producto no existe o no está disponible.")
    _, created = Favorite.objects.get_or_create(user_id=user.id, product_id=product_id)
    return created


def remove_favorite(*, user, product_id: int) -> None:
    """Quitar algo que no estaba no es un error."""
    Favorite.objects.filter(user_id=user.id, product_id=product_id).delete()
