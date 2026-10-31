from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalogo.serializers import ProductSerializer

from . import services


class FavoriteListView(APIView):
    """GET /api/v1/favoritos/  productos favoritos como tarjetas del catálogo."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ProductSerializer(many=True))
    def get(self, request):
        return Response(ProductSerializer(services.list_favorites(user=request.user), many=True).data)


class FavoriteIdsView(APIView):
    """GET /api/v1/favoritos/ids/  ids marcados, para pintar los corazones."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=inline_serializer("FavoriteIds", {"ids": serializers.ListField(child=serializers.IntegerField())}))
    def get(self, request):
        return Response({"ids": services.favorite_ids(user=request.user)})


class FavoriteDetailView(APIView):
    """PUT marca y DELETE desmarca /api/v1/favoritos/<producto_id>/. Ambos son idempotentes."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=None, responses={200: None, 201: None})
    def put(self, request, producto_id):
        created = services.add_favorite(user=request.user, product_id=producto_id)
        return Response(
            {"producto_id": producto_id, "favorito": True},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, producto_id):
        services.remove_favorite(user=request.user, product_id=producto_id)
        return Response(status=status.HTTP_204_NO_CONTENT)