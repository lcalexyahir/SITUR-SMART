from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .serializers import PaymentSerializer


class PaymentPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class CustomerPaymentListView(APIView):
    """GET /api/v1/pagos/?estado=APROBADO  historial de pagos del turista, con resumen."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(
        parameters=[OpenApiParameter("estado", OpenApiTypes.STR, enum=sorted(services.STATES))],
        responses=PaymentSerializer(many=True),
    )
    def get(self, request):
        queryset = services.customer_payments(user=request.user, estado=request.query_params.get("estado"))
        paginator = PaymentPagination()
        page = paginator.paginate_queryset(queryset, request, view=self)
        response = paginator.get_paginated_response(PaymentSerializer(page, many=True).data)
        response.data["resumen"] = services.summary(user=request.user)
        return response


class CustomerPaymentDetailView(APIView):
    """GET /api/v1/pagos/<id>/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=PaymentSerializer)
    def get(self, request, pk):
        return Response(PaymentSerializer(services.customer_payment(user=request.user, payment_id=pk)).data)