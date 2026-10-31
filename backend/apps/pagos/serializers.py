from rest_framework import serializers

from .models import Payment


class PaymentSerializer(serializers.ModelSerializer):
    reserva = serializers.SerializerMethodField()
    empresa = serializers.CharField(source="booking.tenant.trade_name")
    producto = serializers.SerializerMethodField()
    simbolo = serializers.CharField(source="currency.symbol")
    monto = serializers.DecimalField(source="amount", max_digits=12, decimal_places=2)
    metodo = serializers.CharField(source="method")
    estado = serializers.CharField(source="status")
    proveedor = serializers.CharField(source="provider")
    creado_en = serializers.DateTimeField(source="created_at")
    procesado_en = serializers.DateTimeField(source="processed_at", allow_null=True)
    reembolsos = serializers.SerializerMethodField()

    class Meta:
        model = Payment
        fields = (
            "id", "reserva", "empresa", "producto", "simbolo", "monto", "metodo", "estado",
            "proveedor", "creado_en", "procesado_en", "reembolsos",
        )

    def get_reserva(self, payment) -> dict:
        return {"id": payment.booking_id, "codigo": payment.booking.code, "estado": payment.booking.status}

    def get_producto(self, payment) -> dict | None:
        details = list(payment.booking.details.all())
        if not details:
            return None
        product = details[0].slot.product
        return {"id": product.id, "nombre": product.name, "tipo": product.product_type.name}

    def get_reembolsos(self, payment) -> list[dict]:
        field = serializers.DateTimeField()
        return [
            {
                "id": refund.id,
                "estado": refund.status,
                "monto": str(refund.amount),
                "motivo": refund.reason,
                "solicitado_en": field.to_representation(refund.requested_at),
                "procesado_en": field.to_representation(refund.processed_at) if refund.processed_at else None,
            }
            for refund in payment.refunds.all()
        ]