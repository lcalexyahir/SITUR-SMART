"""Reglas del CU45: bandeja de notificaciones y recordatorios del usuario."""

from django.db.models import QuerySet
from django.utils import timezone
from rest_framework.exceptions import NotFound

from .models import Notification

# Filtros de la bandeja: ?filtro=no_leidas | recordatorios
FILTER_UNREAD = "no_leidas"
FILTER_REMINDERS = "recordatorios"


def user_notifications(*, user, filtro: str | None = None) -> QuerySet[Notification]:
    queryset = Notification.objects.filter(user_id=user.id).order_by("-created_at", "-id")
    if filtro == FILTER_UNREAD:
        queryset = queryset.filter(read_at__isnull=True)
    elif filtro == FILTER_REMINDERS:
        queryset = queryset.filter(kind__startswith=Notification.REMINDER_PREFIX)
    return queryset


def unread_counts(*, user) -> dict:
    """Lo consulta la campana de la app, por eso son dos COUNT simples."""
    unread = Notification.objects.filter(user_id=user.id, read_at__isnull=True)
    return {
        "no_leidas": unread.count(),
        "recordatorios_no_leidos": unread.filter(kind__startswith=Notification.REMINDER_PREFIX).count(),
    }


def own_notification(*, user, notification_id: int) -> Notification:
    notification = Notification.objects.filter(user_id=user.id, id=notification_id).first()
    if notification is None:
        raise NotFound("Notificación no encontrada.")
    return notification


def mark_read(*, user, notification_id: int) -> Notification:
    notification = own_notification(user=user, notification_id=notification_id)
    if notification.read_at is None:
        notification.read_at = timezone.now()
        notification.save(update_fields=["read_at"])
    return notification


def mark_all_read(*, user) -> int:
    return Notification.objects.filter(user_id=user.id, read_at__isnull=True).update(read_at=timezone.now())


def delete_notification(*, user, notification_id: int) -> None:
    own_notification(user=user, notification_id=notification_id).delete()


def delete_read(*, user) -> int:
    """Limpia la bandeja: borra solo los avisos ya leídos."""
    deleted, _ = Notification.objects.filter(user_id=user.id, read_at__isnull=False).delete()
    return deleted