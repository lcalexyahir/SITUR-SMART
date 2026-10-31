from rest_framework import serializers


class PackageInputSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=120, trim_whitespace=True)
    ciudad_id = serializers.IntegerField(required=False, allow_null=True)
    fecha_inicio = serializers.DateField()
    fecha_fin = serializers.DateField()
    personas = serializers.IntegerField(min_value=1, max_value=50)


class ComponentInputSerializer(serializers.Serializer):
    producto_id = serializers.IntegerField()
    fecha_inicio = serializers.DateField()
    fecha_fin = serializers.DateField(required=False, allow_null=True)
    cantidad = serializers.IntegerField(min_value=1, max_value=50)
    huespedes = serializers.IntegerField(required=False, allow_null=True, min_value=1, max_value=50)

    def to_service_values(self) -> dict:
        data = self.validated_data
        return {
            "product_id": data["producto_id"],
            "start_date": data["fecha_inicio"],
            "end_date": data.get("fecha_fin"),
            "quantity": data["cantidad"],
            "guests": data.get("huespedes"),
        }


class QuoteInputSerializer(serializers.Serializer):
    guardar = serializers.BooleanField(default=False)