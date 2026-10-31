from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalogo.serializers import ProductSerializer

from . import services
from .serializers import ComponentInputSerializer, PackageInputSerializer, QuoteInputSerializer


class PackageCatalogView(APIView):
    """GET /api/v1/paquetes/catalogo/?q=&tipo=&ciudad_id=  servicios que se pueden sumar."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(
        parameters=[
            OpenApiParameter("q", OpenApiTypes.STR),
            OpenApiParameter("tipo", OpenApiTypes.STR, description="HABITACION, TOUR, EXPERIENCIA, ATRACCION o RESTAURANTE"),
            OpenApiParameter("ciudad_id", OpenApiTypes.INT),
        ],
        responses=ProductSerializer(many=True),
    )
    def get(self, request):
        city = request.query_params.get("ciudad_id")
        products = services.catalog(
            search=(request.query_params.get("q") or "").strip() or None,
            type_code=request.query_params.get("tipo") or None,
            city_id=int(city) if city and city.isdigit() else None,
        )
        return Response(ProductSerializer(products, many=True).data)


class PackageListView(APIView):
    """GET y POST /api/v1/paquetes/"""

    permission_classes = (IsAuthenticated,)

    def get(self, request):
        packages = services.list_packages(request.user)
        return Response([services.package_data(package, detail=False) for package in packages])

    @extend_schema(request=PackageInputSerializer)
    def post(self, request):
        data = PackageInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        package = services.create_package(request.user, data.validated_data)
        return Response(services.package_data(package), status=status.HTTP_201_CREATED)


class PackageDetailView(APIView):
    """GET, PUT y DELETE /api/v1/paquetes/<id>/"""

    permission_classes = (IsAuthenticated,)

    def get(self, request, pk):
        return Response(services.package_data(services.owned_package(request.user, pk)))

    @extend_schema(request=PackageInputSerializer)
    def put(self, request, pk):
        data = PackageInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(services.package_data(services.update_package(request.user, pk, data.validated_data)))

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, pk):
        services.delete_package(request.user, pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PackageComponentListView(APIView):
    """POST /api/v1/paquetes/<id>/componentes/  agrega un servicio."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=ComponentInputSerializer)
    def post(self, request, pk):
        data = ComponentInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        package = services.add_component(request.user, pk, data.to_service_values())
        return Response(services.package_data(package), status=status.HTTP_201_CREATED)


class PackageComponentDetailView(APIView):
    """DELETE /api/v1/paquetes/<id>/componentes/<componente_id>/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None)
    def delete(self, request, pk, component_id):
        return Response(services.package_data(services.remove_component(request.user, pk, component_id)))


class PackageQuoteView(APIView):
    """POST /api/v1/paquetes/<id>/cotizar/  {"guardar": true} lo deja como GUARDADO."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=QuoteInputSerializer)
    def post(self, request, pk):
        data = QuoteInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        package = services.quote_package(request.user, pk, save=data.validated_data["guardar"])
        return Response(services.package_data(package))