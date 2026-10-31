from django.urls import path

from .views import (
    DeleteReadView,
    MarkAllReadView,
    MarkReadView,
    NotificationDetailView,
    NotificationListView,
    UnreadCountView,
)

urlpatterns = [
    path("", NotificationListView.as_view(), name="notification-list"),
    path("no-leidas/", UnreadCountView.as_view(), name="notification-unread"),
    path("leer-todas/", MarkAllReadView.as_view(), name="notification-read-all"),
    path("limpiar-leidas/", DeleteReadView.as_view(), name="notification-delete-read"),
    path("<int:pk>/", NotificationDetailView.as_view(), name="notification-detail"),
    path("<int:pk>/leer/", MarkReadView.as_view(), name="notification-read"),
]