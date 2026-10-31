import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    """
    Registra en Django la tabla notificacion que ya existe en PostgreSQL.
    El modelo es managed=False: esta migración NO ejecuta SQL sobre la base.
    """

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Notification",
            fields=[
                ("id", models.BigAutoField(primary_key=True, serialize=False)),
                ("kind", models.CharField(db_column="tipo", max_length=40)),
                ("title", models.CharField(db_column="titulo", max_length=150)),
                ("message", models.TextField(db_column="mensaje")),
                ("data", models.JSONField(db_column="datos", default=dict)),
                ("read_at", models.DateTimeField(blank=True, db_column="leida_en", null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_column="creado_en")),
                (
                    "user",
                    models.ForeignKey(
                        db_column="id_usuario",
                        on_delete=django.db.models.deletion.DO_NOTHING,
                        related_name="notifications",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "notificacion",
                "ordering": ("-created_at", "-id"),
                "managed": False,
            },
        ),
    ]