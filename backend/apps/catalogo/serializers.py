from rest_framework import serializers

from .models import Product, ProductType


class ProductTypeSerializer(serializers.ModelSerializer):
    codigo = serializers.CharField(source="code")
    nombre = serializers.CharField(source="name")

    class Meta:
        model = ProductType
        fields = ("id", "codigo", "nombre")


class ProductSerializer(serializers.ModelSerializer):
    nombre = serializers.CharField(source="name")
    descripcion = serializers.CharField(source="description", allow_null=True)
    precio = serializers.DecimalField(source="base_price", max_digits=12, decimal_places=2)
    moneda = serializers.CharField(source="currency.symbol")
    capacidad_maxima = serializers.IntegerField(source="max_capacity")
    imagen_url = serializers.CharField(source="image_url", allow_null=True)
    localidad = serializers.CharField(source="locality", allow_null=True)
    tipo = ProductTypeSerializer(source="product_type")
    ciudad = serializers.SerializerMethodField()
    empresa = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = (
            "id",
            "nombre",
            "descripcion",
            "precio",
            "moneda",
            "capacidad_maxima",
            "imagen_url",
            "localidad",
            "tipo",
            "ciudad",
            "empresa",
        )

    def get_ciudad(self, product) -> str:
        return f"{product.city.name}, {product.city.country.name}"

    def get_empresa(self, product) -> dict:
        return {"id": product.tenant_id, "nombre": product.tenant.trade_name}