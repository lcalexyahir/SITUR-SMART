import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Registra en Django las tablas pais y ciudad que ya existen en PostgreSQL.
    Los modelos son managed=False: esta migracion NO ejecuta SQL.
    """

    dependencies = [
        ("tenancy", "0002_currency_plan_subscription"),
    ]

    operations = [
        migrations.CreateModel(
            name="Country",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("iso_code", models.CharField(db_column="codigo_iso", max_length=3, unique=True)),
                ("name", models.CharField(db_column="nombre", max_length=100, unique=True)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_column="creado_en")),
            ],
            options={
                "db_table": "pais",
                "ordering": ("name",),
                "managed": False,
            },
        ),
        migrations.CreateModel(
            name="City",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("name", models.CharField(db_column="nombre", max_length=120)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_column="creado_en")),
                (
                    "country",
                    models.ForeignKey(
                        db_column="id_pais",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="cities",
                        to="tenancy.country",
                    ),
                ),
            ],
            options={
                "db_table": "ciudad",
                "ordering": ("name",),
                "managed": False,
            },
        ),
    ]