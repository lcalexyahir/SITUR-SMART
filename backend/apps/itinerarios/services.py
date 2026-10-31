"""Itinerarios del turista: el plan de un viaje día por día (mismas reglas que la web)."""

from datetime import date, time, timedelta

from django.db.models import Count
from rest_framework.exceptions import NotFound, ValidationError

from apps.catalogo.models import Product
from apps.catalogo.views import published_products
from apps.tenancy.models import City

from .models import Itinerary, ItineraryActivity

MAX_DAYS = 60


# --- Itinerarios -----------------------------------------------------------------


def list_itineraries(*, user):
    return (
        Itinerary.objects.filter(user_id=user.id)
        .select_related("city")
        .annotate(activity_count=Count("activities"))
        .order_by("-start_date", "-id")
    )


def get_itinerary(*, user, itinerary_id: int) -> Itinerary:
    itinerary = Itinerary.objects.select_related("city").filter(user_id=user.id, id=itinerary_id).first()
    if itinerary is None:
        raise NotFound("Itinerario no encontrado.")
    return itinerary


def _check_range(start: date, end: date) -> None:
    if end < start:
        raise ValidationError({"fin": "La fecha de regreso no puede ser anterior a la de salida."})
    if (end - start).days >= MAX_DAYS:
        raise ValidationError({"fin": f"Un itinerario puede durar hasta {MAX_DAYS} días."})


def _city(city_id: int | None) -> City | None:
    if city_id is None:
        return None
    city = City.objects.filter(id=city_id).first()
    if city is None:
        raise ValidationError({"ciudad_id": "Ciudad no encontrada."})
    return city


def create_itinerary(*, user, name: str, start: date, end: date, city_id=None, notes=None) -> Itinerary:
    _check_range(start, end)
    return Itinerary.objects.create(
        user=user, name=name, start_date=start, end_date=end, city=_city(city_id), notes=notes or None
    )


def update_itinerary(*, user, itinerary_id: int, name: str, start: date, end: date, city_id=None, notes=None) -> Itinerary:
    itinerary = get_itinerary(user=user, itinerary_id=itinerary_id)
    _check_range(start, end)
    outside = itinerary.activities.exclude(date__range=(start, end)).count()
    if outside:
        raise ValidationError(
            {
                "inicio": (
                    f"{outside} {'actividad queda' if outside == 1 else 'actividades quedan'} "
                    "fuera de las nuevas fechas. Muévelas o bórralas primero."
                )
            }
        )
    itinerary.name = name
    itinerary.start_date, itinerary.end_date = start, end
    itinerary.city = _city(city_id)
    itinerary.notes = notes or None
    itinerary.save()
    return itinerary


def delete_itinerary(*, user, itinerary_id: int) -> None:
    get_itinerary(user=user, itinerary_id=itinerary_id).delete()


# --- Actividades -------------------------------------------------------------------


def _check_day(itinerary: Itinerary, day: date) -> None:
    if not itinerary.start_date <= day <= itinerary.end_date:
        raise ValidationError({"fecha": "La fecha tiene que estar dentro del viaje."})


def _product(product_id: int) -> Product:
    product = published_products().filter(id=product_id).first()
    if product is None:
        raise ValidationError({"producto_id": "El producto no existe o no está disponible."})
    return product


def add_activity(
    *, user, itinerary_id: int, day: date, at: time | None = None,
    product_id: int | None = None, title: str | None = None, note: str | None = None,
) -> ItineraryActivity:
    itinerary = get_itinerary(user=user, itinerary_id=itinerary_id)
    _check_day(itinerary, day)
    product = _product(product_id) if product_id is not None else None
    title = (title or "").strip() or (product.name if product else "")
    if not title:
        raise ValidationError({"titulo": "Escribe qué vas a hacer o elige un producto."})
    return ItineraryActivity.objects.create(
        itinerary=itinerary, date=day, time=at, product=product, title=title[:150], note=note or None
    )


def _activity(*, user, itinerary_id: int, activity_id: int) -> ItineraryActivity:
    activity = (
        ItineraryActivity.objects.select_related("itinerary")
        .filter(id=activity_id, itinerary_id=itinerary_id, itinerary__user_id=user.id)
        .first()
    )
    if activity is None:
        raise NotFound("Actividad no encontrada.")
    return activity


def update_activity(*, user, itinerary_id: int, activity_id: int, day: date, at: time | None,
                    title: str | None, note: str | None) -> ItineraryActivity:
    """Cambia día, hora, título o nota. El producto no cambia: se borra y se agrega otro."""
    activity = _activity(user=user, itinerary_id=itinerary_id, activity_id=activity_id)
    _check_day(activity.itinerary, day)
    title = (title or "").strip()
    if not title:
        raise ValidationError({"titulo": "El título no puede quedar vacío."})
    activity.date, activity.time = day, at
    activity.title, activity.note = title[:150], note or None
    activity.save()
    return activity


def delete_activity(*, user, itinerary_id: int, activity_id: int) -> None:
    _activity(user=user, itinerary_id=itinerary_id, activity_id=activity_id).delete()


# --- Vista por días -------------------------------------------------------------------


def build_days(itinerary: Itinerary) -> list[dict]:
    """Un bloque por día del viaje con sus actividades ordenadas por hora."""
    start, end = itinerary.start_date, itinerary.end_date
    days = {start + timedelta(days=offset): [] for offset in range((end - start).days + 1)}

    activities = list(itinerary.activities.all())
    visible = {
        product.id: product
        for product in published_products().filter(id__in={a.product_id for a in activities if a.product_id})
    }
    for activity in activities:
        # Un producto que dejó de publicarse no se muestra; queda el título.
        activity.visible_product = visible.get(activity.product_id)
        days.setdefault(activity.date, []).append(activity)

    for items in days.values():
        items.sort(key=lambda a: (a.time is not None, a.time or time.min, a.id))
    return [{"fecha": day, "actividades": items} for day, items in sorted(days.items())]


def cities():
    return City.objects.select_related("country").order_by("name")