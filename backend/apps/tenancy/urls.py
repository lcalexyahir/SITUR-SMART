from django.urls import path

from .views import (
    AssignSubscriptionView,
    RenewSubscriptionView,
    SuspendSubscriptionView,
    TenantDetailView,
    TenantListCreateView,
    TenantStatusView,
    TenantSubscriptionView,
)

urlpatterns = [
    path("", TenantListCreateView.as_view(), name="tenant-list-create"),
    path("<int:pk>/", TenantDetailView.as_view(), name="tenant-detail"),
    path("<int:pk>/estado/", TenantStatusView.as_view(), name="tenant-status"),
    path("<int:pk>/suscripcion/", TenantSubscriptionView.as_view(), name="tenant-subscription"),
    path("<int:pk>/suscripcion/asignar/", AssignSubscriptionView.as_view(), name="tenant-subscription-assign"),
    path("<int:pk>/suscripcion/renovar/", RenewSubscriptionView.as_view(), name="tenant-subscription-renew"),
    path("<int:pk>/suscripcion/suspender/", SuspendSubscriptionView.as_view(), name="tenant-subscription-suspend"),
]