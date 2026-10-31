from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.common.views import ApiRootView, HealthView
from apps.tenancy.views import PlanListView

urlpatterns = [
    path("", ApiRootView.as_view(), name="api-root"),
    path("admin/", admin.site.urls),
    path("api/v1/health/", HealthView.as_view(), name="health"),
    path("api/v1/auth/", include("apps.accounts.urls")),
    path("api/v1/tenants/", include("apps.tenancy.urls")),
    path("api/v1/planes/", PlanListView.as_view(), name="plan-list"),
    path("api/v1/catalogo/", include("apps.catalogo.urls")),
    path("api/v1/", include("apps.rbac.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/v1/audit/", include("apps.audit.urls")),
    # CU35: calificaciones y reseñas (incluye catalogo/productos/<id>/resenas/).
    path("api/v1/", include("apps.resenas.urls")),
    # CU45: notificaciones y recordatorios.
    path("api/v1/notificaciones/", include("apps.notificaciones.urls")),
    # Módulos del turista: favoritos, itinerarios, paquetes personalizados (CU39) e historial de pagos.
    path("api/v1/favoritos/", include("apps.favoritos.urls")),
    path("api/v1/itinerarios/", include("apps.itinerarios.urls")),
    path("api/v1/paquetes/", include("apps.paquetes.urls")),
    path("api/v1/pagos/", include("apps.pagos.urls")),
]