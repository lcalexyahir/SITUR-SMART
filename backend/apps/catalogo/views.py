from django.db.models import Q
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.tenancy.models import Subscription, Tenant
from apps.tenancy.services import expire_due_subscriptions

from .models import Product, ProductType
from .serializers import ProductSerializer, ProductTypeSerializer

MAX_RESULTS = 100


def published_products():
    """
    Productos visibles en el marketplace: publicados por empresas ACTIVAS
    con suscripcion vigente.
    """
    expire_due_subscriptions()
    operational_tenants = Subscription.objects.filter(
        status=Subscription.Status.ACTIVE,
        tenant__status=Tenant.Status.ACTIVE,
    ).values("tenant_id")
    return Product.objects.select_related("tenant", "product_type", "city__country", "currency").filter(
        status=Product.Status.PUBLISHED,
        tenant_id__in=operational_tenants,
    )


class ProductTypeListView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ProductTypeSerializer(many=True))
    def get(self, request):
        return Response(ProductTypeSerializer(ProductType.objects.order_by("name"), many=True).data)


class ProductListView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(
        parameters=[
            OpenApiParameter("q", OpenApiTypes.STR, description="Texto a buscar"),
            OpenApiParameter("tipo", OpenApiTypes.INT, description="Id del tipo de producto"),
        ],
        responses=ProductSerializer(many=True),
    )
    def get(self, request):
        products = published_products()

        query = (request.query_params.get("q") or "").strip()
        if query:
            products = products.filter(
                Q(name__icontains=query)
                | Q(description__icontains=query)
                | Q(locality__icontains=query)
                | Q(city__name__icontains=query)
                | Q(tenant__trade_name__icontains=query)
            )

        product_type = request.query_params.get("tipo")
        if product_type and product_type.isdigit():
            products = products.filter(product_type_id=int(product_type))

        return Response(ProductSerializer(products.order_by("name")[:MAX_RESULTS], many=True).data)


class ProductDetailView(APIView):
    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ProductSerializer)
    def get(self, request, pk):
        product = published_products().filter(pk=pk).first()
        if product is None:
            raise NotFound("El producto no existe o no está disponible.")
        return Response(ProductSerializer(product).data)