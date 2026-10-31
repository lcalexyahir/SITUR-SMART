from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .serializers import NotificationSerializer, UnreadSerializer


class NotificationPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class NotificationListView(APIView):
    """GET /api/v1/notificaciones/?filtro=no_leidas|recordatorios"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(
        parameters=[
            OpenApiParameter(
                "filtro",
                OpenApiTypes.STR,
                enum=[services.FILTER_UNREAD, services.FILTER_REMINDERS],
                description="Sin filtro devuelve todas",
            ),
        ],
        responses=NotificationSerializer(many=True),
    )
    def get(self, request):
        filtro = request.query_params.get("filtro")
        paginator = NotificationPagination()
        page = paginator.paginate_queryset(
            services.user_notifications(user=request.user, filtro=filtro), request, view=self
        )
        return paginator.get_paginated_response(NotificationSerializer(page, many=True).data)


class UnreadCountView(APIView):
    """GET /api/v1/notificaciones/no-leidas/  contador para la campana."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=UnreadSerializer)
    def get(self, request):
        return Response(services.unread_counts(user=request.user))


class MarkReadView(APIView):
    """POST /api/v1/notificaciones/<id>/leer/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses=NotificationSerializer)
    def post(self, request, pk):
        notification = services.mark_read(user=request.user, notification_id=pk)
        return Response(NotificationSerializer(notification).data)


class MarkAllReadView(APIView):
    """POST /api/v1/notificaciones/leer-todas/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses={204: None})
    def post(self, request):
        services.mark_all_read(user=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class NotificationDetailView(APIView):
    """DELETE /api/v1/notificaciones/<id>/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, pk):
        services.delete_notification(user=request.user, notification_id=pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class DeleteReadView(APIView):
    """POST /api/v1/notificaciones/limpiar-leidas/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses={204: None})
    def post(self, request):
        services.delete_read(user=request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)