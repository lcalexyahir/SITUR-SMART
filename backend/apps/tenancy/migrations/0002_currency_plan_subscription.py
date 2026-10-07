import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Registra en Django las tablas moneda, plan y suscripcion que ya existen
    en PostgreSQL. Los modelos son managed=False, por lo que esta migracion
    NO ejecuta SQL ni modifica la base de datos.
    """

    dependencies = [
        ("tenancy", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Currency",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("iso_code", models.CharField(db_column="codigo_iso", max_length=3, unique=True)),
                ("name", models.CharField(db_column="nombre", max_length=80)),
                ("symbol", models.CharField(db_column="simbolo", max_length=10)),
                ("decimals", models.SmallIntegerField(db_column="decimales", default=2)),
            ],
            options={
                "db_table": "moneda",
                "ordering": ("iso_code",),
                "managed": False,
            },
        ),
        migrations.CreateModel(
            name="Plan",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("code", models.CharField(db_column="codigo", max_length=50, unique=True)),
                ("name", models.CharField(db_column="nombre", max_length=100, unique=True)),
                ("monthly_price", models.DecimalField(db_column="precio_mensual", decimal_places=2, max_digits=12)),
                ("max_users", models.IntegerField(db_column="max_usuarios")),
                ("max_products", models.IntegerField(db_column="max_productos")),
                (
                    "commission_percentage",
                    models.DecimalField(db_column="porcentaje_comision", decimal_places=2, default=0, max_digits=5),
                ),
                ("active", models.BooleanField(db_column="activo", default=True)),
                (
                    "currency",
                    models.ForeignKey(
                        db_column="id_moneda",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="plans",
                        to="tenancy.currency",
                    ),
                ),
            ],
            options={
                "db_table": "plan",
                "ordering": ("monthly_price",),
                "managed": False,
            },
        ),
        migrations.CreateModel(
            name="Subscription",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("start_date", models.DateField(db_column="fecha_inicio")),
                ("end_date", models.DateField(blank=True, db_column="fecha_fin", null=True)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("ACTIVA", "Activa"),
                            ("VENCIDA", "Vencida"),
                            ("CANCELADA", "Cancelada"),
                            ("SUSPENDIDA", "Suspendida"),
                        ],
                        db_column="estado",
                        default="ACTIVA",
                        max_length=20,
                    ),
                ),
                ("auto_renew", models.BooleanField(db_column="renovacion_automatica", default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_column="creado_en")),
                (
                    "plan",
                    models.ForeignKey(
                        db_column="id_plan",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="subscriptions",
                        to="tenancy.plan",
                    ),
                ),
                (
                    "tenant",
                    models.ForeignKey(
                        db_column="id_tenant",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="subscriptions",
                        to="tenancy.tenant",
                    ),
                ),
            ],
            options={
                "db_table": "suscripcion",
                "ordering": ("-created_at",),
                "managed": False,
            },
        ),
    ]