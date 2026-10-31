"""Historial de pagos del turista: solo consulta, sin pasarela."""

from collections import defaultdict
from decimal import Decimal

from django.db.models import Prefetch, QuerySet
from rest_framework.exceptions import NotFound

from .models import BookingDetail, Payment

STATES = {state.value for state in Payment.State}


def _base() -> QuerySet[Payment]:
    return (
        Payment.objects.select_related("booking__tenant", "currency")
        .prefetch_related(
            Prefetch(
                "booking__details",
                queryset=BookingDetail.objects.select_related("slot__product__product_type").order_by("id"),
            ),
            "refunds",
        )
        .order_by("-created_at", "-id")
    )


def customer_payments(*, user, estado: str | None = None) -> QuerySet[Payment]:
    # La orden pertenece al perfil de cliente, cuyo id es el del usuario.
    queryset = _base().filter(booking__order__customer_id=user.id)
    if estado in STATES:
        queryset = queryset.filter(status=estado)
    return queryset


def customer_payment(*, user, payment_id: int) -> Payment:
    payment = _base().filter(id=payment_id, booking__order__customer_id=user.id).first()
    if payment is None:
        raise NotFound("Pago no encontrado.")
    return payment


def summary(*, user) -> list[dict]:
    """Total aprobado por moneda (descontando reembolsos completados)."""
    totals: dict[str, Decimal] = defaultdict(Decimal)
    counts: dict[str, int] = defaultdict(int)
    approved = Payment.objects.select_related("currency").prefetch_related("refunds").filter(
        booking__order__customer_id=user.id, status=Payment.State.APPROVED
    )
    for payment in approved:
        refunded = sum((r.amount for r in payment.refunds.all() if r.status == "COMPLETADO"), Decimal("0"))
        totals[payment.currency.symbol] += payment.amount - refunded
        counts[payment.currency.symbol] += 1
    return [{"simbolo": symbol, "total": str(total), "pagos": counts[symbol]} for symbol, total in totals.items()]