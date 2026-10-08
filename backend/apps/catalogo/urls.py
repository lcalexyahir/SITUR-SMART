from django.urls import path

from .views import ProductDetailView, ProductListView, ProductTypeListView

urlpatterns = [
    path("tipos/", ProductTypeListView.as_view(), name="catalog-types"),
    path("productos/", ProductListView.as_view(), name="catalog-products"),
    path("productos/<int:pk>/", ProductDetailView.as_view(), name="catalog-product-detail"),
]