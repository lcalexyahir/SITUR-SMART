from django.urls import path

from .views import MyReviewDetailView, MyReviewsView, ProductReviewsView

urlpatterns = [
    path("catalogo/productos/<int:pk>/resenas/", ProductReviewsView.as_view(), name="product-reviews"),
    path("resenas/mias/", MyReviewsView.as_view(), name="my-reviews"),
    path("resenas/<int:pk>/", MyReviewDetailView.as_view(), name="my-review-detail"),
]