import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Registra en Django la tabla resena_producto que ya existe en PostgreSQL.
    El modelo es managed=False: esta migración NO ejecuta SQL sobre la base.
    """

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("catalogo", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ProductReview",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("rating", models.SmallIntegerField(db_column="calificacion")),
                ("comment", models.TextField(db_column="comentario")),
                ("created_at", models.DateTimeField(auto_now_add=True, db_column="creado_en")),
                ("updated_at", models.DateTimeField(auto_now=True, db_column="actualizado_en")),
                (
                    "user",
                    models.ForeignKey(
                        db_column="id_usuario",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="product_reviews",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "product",
                    models.ForeignKey(
                        db_column="id_producto",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="reviews",
                        to="catalogo.product",
                    ),
                ),
            ],
            options={
                "db_table": "resena_producto",
                "ordering": ("-created_at", "-id"),
                "managed": False,
            },
        ),
    ]