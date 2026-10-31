"""
CU39: paquetes personalizados del turista.

El móvil arma y cotiza el paquete; la compra (con pago) se hace en la web.
Una cotización es informativa: no aparta cupos ni crea reservas.

Reglas iguales a las de la web, simplificadas: no se aplican promociones
(la web vuelve a cotizar al comprar) y en tours con salidas programadas se
asigna la primera salida abierta del día.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.core.exceptions import ObjectDoesNotExist
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import APIException, NotFound, ValidationError

from apps.catalogo.models import Product
from apps.catalogo.views import published_products
from apps.tenancy.models import City

from .models import Availability, CustomPackage, PackageComponent, PackagePurchase, Room, TourDetail

ROOM_CODE = "HABITACION"
DEPARTURE_CODES = frozenset({"TOUR", "EXPERIENCIA"})
COMPONENT_CODES = frozenset({ROOM_CODE, "TOUR", "EXPERIENCIA", "ATRACCION", "RESTAURANTE"})
MAX_COMPONENTS = 20
MAX_NIGHTS = 30
MAX_TRAVELERS = 50


def _zone():
    return ZoneInfo(settings.TIME_ZONE)


# --- Catálogo ---------------------------------------------------------------------


def catalog(*, search=None, type_code=None, city_id=None):
    """Servicios individuales que se pueden sumar a un paquete (en bolivianos y con precio)."""
    query = published_products().filter(
        product_type__code__in=COMPONENT_CODES,
        currency__iso_code="BOB",
        base_price__gt=0,
    )
    if search:
        query = query.filter(
            Q(name__icontains=search) | Q(tenant__trade_name__icontains=search) | Q(city__name__icontains=search)
        )
    if type_code:
        query = query.filter(product_type__code=type_code)
    if city_id:
        query = query.filter(city_id=city_id)
    return query.order_by("name")[:100]


# --- Paquete ------------------------------------------------------------------------


def owned_package(user, package_id, *, lock=False) -> CustomPackage:
    query = CustomPackage.objects.select_related("city").filter(id=package_id, user_id=user.id)
    if lock:
        query = query.select_for_update()
    package = query.first()
    if package is None:
        raise NotFound("Paquete no encontrado.")
    return package


def purchase_of(package) -> PackagePurchase | None:
    try:
        return package.purchase
    except ObjectDoesNotExist:
        return None


def ensure_editable(package) -> None:
    if PackagePurchase.objects.filter(package_id=package.id).exists():
        raise ValidationError({"detail": "El paquete ya tiene una compra y no puede modificarse."})


def _check_package(start: date, end: date, travelers: int, city_id) -> None:
    if end < start:
        raise ValidationError({"fecha_fin": "Debe ser igual o posterior a la fecha de inicio."})
    if start < timezone.localdate():
        raise ValidationError({"fecha_inicio": "Elige una fecha desde hoy en adelante."})
    if travelers < 1 or travelers > MAX_TRAVELERS:
        raise ValidationError({"personas": f"Indica entre 1 y {MAX_TRAVELERS} viajeros."})
    if city_id is not None and not City.objects.filter(id=city_id).exists():
        raise ValidationError({"ciudad_id": "Ciudad no encontrada."})


def list_packages(user):
    return CustomPackage.objects.select_related("city").filter(user_id=user.id).order_by("-updated_at", "-id")


@transaction.atomic
def create_package(user, values) -> CustomPackage:
    _check_package(values["fecha_inicio"], values["fecha_fin"], values["personas"], values.get("ciudad_id"))
    return CustomPackage.objects.create(
        user=user,
        name=values["nombre"].strip(),
        city_id=values.get("ciudad_id"),
        start_date=values["fecha_inicio"],
        end_date=values["fecha_fin"],
        travelers=values["personas"],
        status=CustomPackage.Status.DRAFT,
        total=Decimal("0"),
    )


@transaction.atomic
def update_package(user, package_id, values) -> CustomPackage:
    package = owned_package(user, package_id, lock=True)
    ensure_editable(package)
    _check_package(values["fecha_inicio"], values["fecha_fin"], values["personas"], values.get("ciudad_id"))
    package.name = values["nombre"].strip()
    package.city_id = values.get("ciudad_id")
    package.start_date = values["fecha_inicio"]
    package.end_date = values["fecha_fin"]
    package.travelers = values["personas"]
    package.status = CustomPackage.Status.DRAFT
    package.save()
    _refresh_if_valid(package)
    return package


@transaction.atomic
def delete_package(user, package_id) -> None:
    package = owned_package(user, package_id, lock=True)
    ensure_editable(package)
    package.components.all().delete()
    package.delete()


# --- Cotización de un servicio ----------------------------------------------------------


@dataclass
class Quote:
    product: Product
    start: date
    end: date | None
    quantity: int
    guests: int | None
    departure: Availability | None
    unit_price: Decimal
    total: Decimal


def _is_daily(slot: Availability) -> bool:
    start = timezone.localtime(slot.start, _zone())
    end = timezone.localtime(slot.end, _zone())
    return start.time() == time.min and end == start + timedelta(days=1)


def _scheduled_departures(product_id: int, day: date) -> list[Availability]:
    start = datetime.combine(day, time.min, tzinfo=_zone())
    slots = Availability.objects.filter(
        product_id=product_id, start__gte=start, start__lt=start + timedelta(days=1)
    ).order_by("start", "id")
    return [slot for slot in slots if not _is_daily(slot)]


def quote_component(package: CustomPackage, values: dict, *, exclude_id=None) -> Quote:
    """Valida un servicio dentro del paquete y calcula su precio."""
    product = (
        published_products()
        .filter(id=values["product_id"], product_type__code__in=COMPONENT_CODES)
        .first()
    )
    if product is None:
        raise ValidationError({"producto_id": "Ese servicio no está disponible para paquetes."})
    if product.currency.iso_code != "BOB" or not product.base_price or product.base_price <= 0:
        raise ValidationError({"producto_id": "Por ahora el paquete admite productos con precio en bolivianos."})

    start = values["start_date"]
    end = values.get("end_date")
    quantity = values["quantity"]
    guests = values.get("guests")
    code = product.product_type.code

    if start < timezone.localdate():
        raise ValidationError({"fecha_inicio": "Elige una fecha desde hoy en adelante."})
    if start < package.start_date or start > package.end_date:
        raise ValidationError({"fecha_inicio": "La fecha debe estar dentro del viaje."})
    if quantity < 1:
        raise ValidationError({"cantidad": "La cantidad mínima es 1."})

    price = product.base_price
    departure = None

    if code == ROOM_CODE:
        if end is None or end <= start:
            raise ValidationError({"fecha_fin": "La salida del hospedaje debe ser posterior a la llegada."})
        if end > package.end_date + timedelta(days=1):
            raise ValidationError({"fecha_fin": "La salida del hospedaje debe estar dentro del viaje."})
        nights = (end - start).days
        if nights > MAX_NIGHTS:
            raise ValidationError({"fecha_fin": f"Se puede reservar hasta {MAX_NIGHTS} noches seguidas."})
        room = Room.objects.filter(product_id=product.id).first()
        available_rooms = room.quantity if room else 1
        if quantity > available_rooms:
            raise ValidationError({"cantidad": f"Este hospedaje tiene {available_rooms} habitaciones de este tipo."})
        if guests is None:
            raise ValidationError({"huespedes": "Indica cuántos huéspedes se alojan."})
        if guests < quantity:
            raise ValidationError({"huespedes": "Cada habitación necesita al menos un huésped."})
        if guests > package.travelers:
            raise ValidationError({"huespedes": "No puede exceder la cantidad de viajeros del paquete."})
        if guests > quantity * product.max_capacity:
            needed = -(-guests // product.max_capacity)
            raise ValidationError(
                {"huespedes": f"Para {guests} huéspedes necesitas al menos {needed} habitaciones de este tipo."}
            )
        total = price * quantity * nights
    else:
        end, guests = None, None
        if quantity > package.travelers:
            raise ValidationError({"cantidad": "No puede exceder la cantidad de viajeros del paquete."})
        if quantity > product.max_capacity:
            raise ValidationError({"cantidad": f"El máximo es de {product.max_capacity} personas."})
        if code in DEPARTURE_CODES:
            now = timezone.now()
            open_departures = [
                slot for slot in _scheduled_departures(product.id, start) if not slot.closed and slot.start > now
            ]
            if open_departures:
                departure = open_departures[0]
                others = PackageComponent.objects.filter(package=package, departure__isnull=False)
                if exclude_id:
                    others = others.exclude(id=exclude_id)
                for other in others.select_related("departure"):
                    if other.departure.start < departure.end and departure.start < other.departure.end:
                        raise ValidationError({"fecha_inicio": "Esta salida se superpone con otro servicio del paquete."})
            elif TourDetail.objects.filter(product_id=product.id).exists():
                raise ValidationError({"fecha_inicio": "Este tour no tiene salidas ese día. Elige otra fecha."})
        total = price * quantity

    return Quote(
        product=product, start=start, end=end, quantity=quantity, guests=guests,
        departure=departure, unit_price=price, total=total,
    )


def _values(component: PackageComponent) -> dict:
    return {
        "product_id": component.product_id,
        "start_date": component.start_date,
        "end_date": component.end_date,
        "quantity": component.quantity,
        "guests": component.guests,
    }


def _message(detail) -> str:
    if isinstance(detail, dict):
        return "; ".join(_message(value) for value in detail.values())
    if isinstance(detail, list):
        return "; ".join(_message(value) for value in detail)
    return str(detail)


def _recalculate_total(package: CustomPackage) -> None:
    package.total = sum((item.total for item in package.components.all()), Decimal("0"))


def _refresh_if_valid(package: CustomPackage) -> None:
    """Recalcula precios si todos los servicios siguen siendo válidos con las nuevas fechas."""
    quoted = []
    for component in package.components.all():
        try:
            quoted.append((component, quote_component(package, _values(component), exclude_id=component.id)))
        except APIException:
            return
    for component, quote in quoted:
        component.unit_price, component.total, component.departure = quote.unit_price, quote.total, quote.departure
        component.save(update_fields=["unit_price", "total", "departure"])
    _recalculate_total(package)
    package.save(update_fields=["total", "updated_at"])


@transaction.atomic
def add_component(user, package_id, values) -> CustomPackage:
    package = owned_package(user, package_id, lock=True)
    ensure_editable(package)
    if package.components.count() >= MAX_COMPONENTS:
        raise ValidationError({"componentes": f"El máximo es {MAX_COMPONENTS} servicios por paquete."})
    quote = quote_component(package, values)
    duplicate = package.components.filter(
        product_id=quote.product.id, start_date=quote.start, end_date=quote.end
    ).exists()
    if duplicate:
        raise ValidationError({"producto_id": "Ese servicio con las mismas fechas ya está incluido."})
    PackageComponent.objects.create(
        package=package, product=quote.product, start_date=quote.start, end_date=quote.end,
        quantity=quote.quantity, guests=quote.guests, departure=quote.departure,
        unit_price=quote.unit_price, total=quote.total,
    )
    _recalculate_total(package)
    package.status = CustomPackage.Status.DRAFT
    package.save(update_fields=["total", "status", "updated_at"])
    return package


@transaction.atomic
def remove_component(user, package_id, component_id) -> CustomPackage:
    package = owned_package(user, package_id, lock=True)
    ensure_editable(package)
    deleted, _ = package.components.filter(id=component_id).delete()
    if not deleted:
        raise NotFound("Servicio no encontrado en este paquete.")
    _recalculate_total(package)
    package.status = CustomPackage.Status.DRAFT
    package.save(update_fields=["total", "status", "updated_at"])
    return package


@transaction.atomic
def quote_package(user, package_id, *, save: bool) -> CustomPackage:
    """Vuelve a cotizar todos los servicios; con save=True queda como GUARDADO."""
    package = owned_package(user, package_id, lock=True)
    ensure_editable(package)
    components = list(package.components.all())
    if not components:
        raise ValidationError({"componentes": "Agrega al menos un servicio."})
    quotes, problems = [], []
    for component in components:
        try:
            quotes.append((component, quote_component(package, _values(component), exclude_id=component.id)))
        except APIException as exc:
            problems.append(f"{component.product.name}: {_message(exc.detail)}")
    if problems:
        raise ValidationError({"componentes": problems})
    for component, quote in quotes:
        component.unit_price, component.total, component.departure = quote.unit_price, quote.total, quote.departure
        component.save(update_fields=["unit_price", "total", "departure"])
    _recalculate_total(package)
    package.status = CustomPackage.Status.SAVED if save else CustomPackage.Status.DRAFT
    package.save(update_fields=["total", "status", "updated_at"])
    return package


# --- Respuesta --------------------------------------------------------------------------


def package_data(package: CustomPackage, *, detail: bool = True) -> dict:
    purchase = purchase_of(package)
    data = {
        "id": package.id,
        "nombre": package.name,
        "ciudad_id": package.city_id,
        "ciudad": package.city.name if package.city_id else None,
        "fecha_inicio": package.start_date.isoformat(),
        "fecha_fin": package.end_date.isoformat(),
        "personas": package.travelers,
        "estado": package.status,
        "total": str(package.total),
        "cantidad_servicios": package.components.count(),
        "actualizado_en": package.updated_at.isoformat() if package.updated_at else None,
        "compra": (
            {"id": purchase.id, "estado": purchase.status, "total": str(purchase.final_amount)} if purchase else None
        ),
        "editable": purchase is None,
    }
    if detail:
        items, warnings = [], []
        for component in package.components.select_related(
            "product__product_type", "product__tenant", "product__city", "departure"
        ):
            error, current_total = None, None
            try:
                current_total = quote_component(package, _values(component), exclude_id=component.id).total
            except APIException as exc:
                error = _message(exc.detail)
                warnings.append(f"{component.product.name}: {error}")
            items.append({
                "id": component.id,
                "producto_id": component.product_id,
                "nombre": component.product.name,
                "tipo": component.product.product_type.name,
                "tipo_codigo": component.product.product_type.code,
                "empresa": component.product.tenant.trade_name,
                "ciudad": component.product.city.name,
                "imagen_url": component.product.image_url,
                "fecha_inicio": component.start_date.isoformat(),
                "fecha_fin": component.end_date.isoformat() if component.end_date else None,
                "cantidad": component.quantity,
                "huespedes": component.guests,
                "hora_inicio": (
                    timezone.localtime(component.departure.start, _zone()).strftime("%H:%M")
                    if component.departure_id else None
                ),
                "precio_unitario": str(component.unit_price),
                "total": str(component.total),
                "disponible": error is None,
                "requiere_revalidacion": error is not None or current_total != component.total,
                "motivo": error,
            })
        data["componentes"] = items
        data["advertencias"] = warnings
        data["requiere_revalidacion"] = any(item["requiere_revalidacion"] for item in items)
    return data