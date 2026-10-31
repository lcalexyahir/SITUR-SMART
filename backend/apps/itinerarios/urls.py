from django.urls import path

from .views import ActivityDetailView, ActivityListView, CityListView, ItineraryDetailView, ItineraryListView

urlpatterns = [
    path("", ItineraryListView.as_view(), name="itinerary-list"),
    path("ciudades/", CityListView.as_view(), name="itinerary-cities"),
    path("<int:pk>/", ItineraryDetailView.as_view(), name="itinerary-detail"),
    path("<int:pk>/actividades/", ActivityListView.as_view(), name="itinerary-activity-list"),
    path("<int:pk>/actividades/<int:activity_id>/", ActivityDetailView.as_view(), name="itinerary-activity-detail"),
]