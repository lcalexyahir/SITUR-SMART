from django.contrib import admin

from .models import Currency, Plan, Subscription, Tenant


@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    list_display = ("trade_name", "legal_name", "subdomain", "status", "contact_email", "created_at")
    list_filter = ("status",)
    search_fields = ("trade_name", "legal_name", "subdomain", "tax_id", "contact_email")
    ordering = ("trade_name",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(Currency)
class CurrencyAdmin(admin.ModelAdmin):
    list_display = ("iso_code", "name", "symbol", "decimals")
    search_fields = ("iso_code", "name")
    ordering = ("iso_code",)


@admin.register(Plan)
class PlanAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "monthly_price", "currency", "max_users", "max_products", "active")
    list_filter = ("active", "currency")
    search_fields = ("code", "name")
    ordering = ("monthly_price",)


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    """
    Solo lectura: las suscripciones se asignan, renuevan y suspenden desde la
    API para que cada operacion quede registrada en la bitacora.
    """

    list_display = ("tenant", "plan", "start_date", "end_date", "status", "auto_renew", "created_at")
    list_filter = ("status", "plan")
    search_fields = ("tenant__trade_name", "plan__name")
    ordering = ("-created_at",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False