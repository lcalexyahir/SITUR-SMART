from django.urls import path

from .views import CustomerPaymentDetailView, CustomerPaymentListView

urlpatterns = [
    path("", CustomerPaymentListView.as_view(), name="customer-payment-list"),
    path("<int:pk>/", CustomerPaymentDetailView.as_view(), name="customer-payment-detail"),
]