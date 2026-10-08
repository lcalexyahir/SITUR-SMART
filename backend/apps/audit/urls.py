from django.urls import path

from .views import SecureLogView

urlpatterns = [
    path("log-seguro/", SecureLogView.as_view(), name="audit-secure-log"),
]