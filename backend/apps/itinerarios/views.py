from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .serializers import (
    ActivityInputSerializer,
    ActivitySerializer,
    CitySerializer,
    ItineraryInputSerializer,
    ItinerarySerializer,
)


def _detail(itinerary) -> dict:
    data = ItinerarySerializer(itinerary).data
    data["dias_detalle"] = [
        {"fecha": day["fecha"].isoformat(), "actividades": ActivitySerializer(day["actividades"], many=True).data}
        for day in services.build_days(itinerary)
    ]
    return data


class ItineraryListView(APIView):
    """GET y POST /api/v1/itinerarios/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ItinerarySerializer(many=True))
    def get(self, request):
        return Response(ItinerarySerializer(services.list_itineraries(user=request.user), many=True).data)

    @extend_schema(request=ItineraryInputSerializer, responses={201: ItinerarySerializer})
    def post(self, request):
        data = ItineraryInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        itinerary = services.create_itinerary(
            user=request.user,
            name=values["nombre"],
            start=values["inicio"],
            end=values["fin"],
            city_id=values.get("ciudad_id"),
            notes=values.get("notas"),
        )
        return Response(_detail(itinerary), status=status.HTTP_201_CREATED)


class ItineraryDetailView(APIView):
    """GET, PUT y DELETE /api/v1/itinerarios/<id>/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=ItinerarySerializer)
    def get(self, request, pk):
        return Response(_detail(services.get_itinerary(user=request.user, itinerary_id=pk)))

    @extend_schema(request=ItineraryInputSerializer, responses=ItinerarySerializer)
    def put(self, request, pk):
        data = ItineraryInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        itinerary = services.update_itinerary(
            user=request.user,
            itinerary_id=pk,
            name=values["nombre"],
            start=values["inicio"],
            end=values["fin"],
            city_id=values.get("ciudad_id"),
            notes=values.get("notas"),
        )
        return Response(_detail(itinerary))

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, pk):
        services.delete_itinerary(user=request.user, itinerary_id=pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ActivityListView(APIView):
    """POST /api/v1/itinerarios/<id>/actividades/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=ActivityInputSerializer, responses={201: ActivitySerializer})
    def post(self, request, pk):
        data = ActivityInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        activity = services.add_activity(
            user=request.user,
            itinerary_id=pk,
            day=values["fecha"],
            at=values.get("hora"),
            product_id=values.get("producto_id"),
            title=values.get("titulo"),
            note=values.get("nota"),
        )
        return Response(ActivitySerializer(activity).data, status=status.HTTP_201_CREATED)


class ActivityDetailView(APIView):
    """PUT y DELETE /api/v1/itinerarios/<id>/actividades/<actividad_id>/"""

    permission_classes = (IsAuthenticated,)

    @extend_schema(request=ActivityInputSerializer, responses=ActivitySerializer)
    def put(self, request, pk, activity_id):
        data = ActivityInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        activity = services.update_activity(
            user=request.user,
            itinerary_id=pk,
            activity_id=activity_id,
            day=values["fecha"],
            at=values.get("hora"),
            title=values.get("titulo"),
            note=values.get("nota"),
        )
        return Response(ActivitySerializer(activity).data)

    @extend_schema(request=None, responses={204: None})
    def delete(self, request, pk, activity_id):
        services.delete_activity(user=request.user, itinerary_id=pk, activity_id=activity_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class CityListView(APIView):
    """GET /api/v1/itinerarios/ciudades/  ciudades para los formularios de viaje y paquete."""

    permission_classes = (IsAuthenticated,)

    @extend_schema(responses=CitySerializer(many=True))
    def get(self, request):
        return Response(CitySerializer(services.cities(), many=True).data)