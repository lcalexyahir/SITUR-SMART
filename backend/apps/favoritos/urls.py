from django.urls import path

from .views import FavoriteDetailView, FavoriteIdsView, FavoriteListView

urlpatterns = [
    path("", FavoriteListView.as_view(), name="favorite-list"),
    path("ids/", FavoriteIdsView.as_view(), name="favorite-ids"),
    path("<int:producto_id>/", FavoriteDetailView.as_view(), name="favorite-detail"),
]