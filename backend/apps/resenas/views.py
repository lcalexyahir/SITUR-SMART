from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .serializers import MyReviewSerializer, ReviewInputSerializer, ReviewSerializer, SummarySerializer


class ReviewPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = "page_size"
    max_page_size = 50


class ProductReviewsView(APIView):
    """
    GET  /api/v1/catalogo/productos/<id>/resenas/  resumen + reseñas paginadas.
    POST /api/v1/catalogo/productos/<id>/resenas/  el turista califica el producto.
    """

    permission_classes = (IsAuthenticated,)

    @extend_schema(
        responses=inline_serializer(
            name="ProductReviewsPage",
            fields={
                "resumen": SummarySerializer(),
                "mi_resena": ReviewSerializer(allow_null=True),
                "puede_resenar": serializers.BooleanField(),
                "count": serializers.IntegerField(),
                "next": serializers.CharField(allow_null=True),
                "previous": serializers.CharField(allow_null=True),
                "results": ReviewSerializer(many=True),
            },
        )
    )
    def get(self, request, pk):
        product = services.visible_product(pk)
        paginator = ReviewPagination()
        page = paginator.paginate_queryset(services.product_reviews(product), request, view=self)
        response = paginator.get_paginated_response(
            ReviewSerializer(page, many=True, context={"request": request}).data
        )

        mine = services.own_review_for_product(user=request.user, product=product)
        response.data = {
            "resumen": services.summary(product),
            "mi_resena": ReviewSerializer(mine, context={"request": request}).data if mine else None,
            "puede_resenar": mine is None and services.is_client(request.user),
            **response.data,
        }
        return response

    @extend_schema(request=ReviewInputSerializer, responses={201: ReviewSerializer})
    def post(self, request, pk):
        data = ReviewInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        review = services.create_review(
            user=request.user,
            product_id=pk,
            rating=data.validated_data["calificacion"],
            comment=data.validated_data["comentario"],
        )
        return Response(ReviewSerializer(review, context={"request": request}).data, status=status.HTTP_201_CREATED)


class MyReviewsView(APIView):
    """GET /api/v1/resenas/mias/  reseñas que escribió el usuario."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=MyReviewSerializer(many=True))
    def get(self, request):
        paginator = ReviewPagination()
        page = paginator.paginate_queryset(services.my_reviews(user=request.user), request, view=self)
        return paginator.get_paginated_response(
            MyReviewSerializer(page, many=True, context={"request": request}).data
        )


class MyReviewDetailView(APIView):
    """
    PUT    /api/v1/resenas/<id>/  edita la calificación y el comentario propios.
    DELETE /api/v1/resenas/<id>/  elimina la reseña propia.
    """

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=ReviewInputSerializer, responses=MyReviewSerializer)
    def put(self, request, pk):
        data = ReviewInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        review = services.update_review(
            user=request.user,
            review_id=pk,
            rating=data.validated_data["calificacion"],
            comment=data.validated_data["comentario"],
        )
        return Response(MyReviewSerializer(review, context={"request": request}).data)

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, pk):
        services.delete_review(user=request.user, review_id=pk)
        return Response(status=status.HTTP_204_NO_CONTENT)