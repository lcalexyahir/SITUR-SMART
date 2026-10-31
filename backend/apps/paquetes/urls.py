from django.urls import path

from .views import (
    PackageCatalogView,
    PackageComponentDetailView,
    PackageComponentListView,
    PackageDetailView,
    PackageListView,
    PackageQuoteView,
)

urlpatterns = [
    path("", PackageListView.as_view(), name="package-list"),
    path("catalogo/", PackageCatalogView.as_view(), name="package-catalog"),
    path("<int:pk>/", PackageDetailView.as_view(), name="package-detail"),
    path("<int:pk>/componentes/", PackageComponentListView.as_view(), name="package-components"),
    path("<int:pk>/componentes/<int:component_id>/", PackageComponentDetailView.as_view(), name="package-component-detail"),
    path("<int:pk>/cotizar/", PackageQuoteView.as_view(), name="package-quote"),
]