from rest_framework import serializers

from .models import Itinerary, ItineraryActivity


class ItineraryInputSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=120, trim_whitespace=True)
    ciudad_id = serializers.IntegerField(required=False, allow_null=True)
    inicio = serializers.DateField()
    fin = serializers.DateField()
    notas = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=2000)


class ActivityInputSerializer(serializers.Serializer):
    fecha = serializers.DateField()
    hora = serializers.TimeField(required=False, allow_null=True)
    producto_id = serializers.IntegerField(required=False, allow_null=True)
    titulo = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=150)
    nota = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=1000)


def _product_data(product) -> dict | None:
    if product is None:
        return None
    return {
        "id": product.id,
        "nombre": product.name,
        "imagen_url": product.image_url,
        "tipo": product.product_type.name,
    }


class ActivitySerializer(serializers.ModelSerializer):
    fecha = serializers.DateField(source="date")
    hora = serializers.SerializerMethodField()
    titulo = serializers.CharField(source="title")
    nota = serializers.CharField(source="note", allow_null=True)
    producto = serializers.SerializerMethodField()

    class Meta:
        model = ItineraryActivity
        fields = ("id", "fecha", "hora", "titulo", "nota", "producto")

    def get_hora(self, activity) -> str | None:
        return activity.time.strftime("%H:%M") if activity.time else None

    def get_producto(self, activity) -> dict | None:
        product = getattr(activity, "visible_product", None)
        if product is None and activity.product_id and not hasattr(activity, "visible_product"):
            product = activity.product
        return _product_data(product)


class ItinerarySerializer(serializers.ModelSerializer):
    nombre = serializers.CharField(source="name")
    ciudad = serializers.SerializerMethodField()
    inicio = serializers.DateField(source="start_date")
    fin = serializers.DateField(source="end_date")
    notas = serializers.CharField(source="notes", allow_null=True)
    dias = serializers.SerializerMethodField()
    actividades = serializers.SerializerMethodField()

    class Meta:
        model = Itinerary
        fields = ("id", "nombre", "ciudad", "inicio", "fin", "notas", "dias", "actividades")

    def get_ciudad(self, itinerary) -> dict | None:
        if itinerary.city_id is None:
            return None
        return {"id": itinerary.city_id, "nombre": itinerary.city.name}

    def get_dias(self, itinerary) -> int:
        return (itinerary.end_date - itinerary.start_date).days + 1

    def get_actividades(self, itinerary) -> int:
        count = getattr(itinerary, "activity_count", None)
        return count if count is not None else itinerary.activities.count()


class CitySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nombre = serializers.CharField(source="name")
    pais = serializers.CharField(source="country.name")