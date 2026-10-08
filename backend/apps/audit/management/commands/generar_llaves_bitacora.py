import hashlib
import secrets

from cryptography.fernet import Fernet
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = (
        "Genera la clave de cifrado de la bitácora y el hash de la llave del desarrollador. "
        "Con --llave puede elegir una llave fácil de recordar; con --solo-llave no se "
        "genera una nueva clave de cifrado."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--llave",
            help="Llave del desarrollador elegida por usted (mínimo 8 caracteres).",
        )
        parser.add_argument(
            "--solo-llave",
            action="store_true",
            help="Solo calcula el hash de la llave; no genera una nueva AUDIT_LOG_KEY.",
        )

    def handle(self, *args, **options):
        developer_key = options.get("llave")
        if developer_key is not None:
            developer_key = developer_key.strip()
            if len(developer_key) < 8:
                raise CommandError("La llave debe tener al menos 8 caracteres.")
        else:
            developer_key = secrets.token_urlsafe(24)

        developer_hash = hashlib.sha256(developer_key.encode("utf-8")).hexdigest()

        self.stdout.write("")
        self.stdout.write(self.style.WARNING("=== Copie en backend/.env (y en las Variables de Railway) ==="))
        if not options["solo_llave"]:
            self.stdout.write(f"AUDIT_LOG_KEY={Fernet.generate_key().decode()}")
        self.stdout.write(f"AUDIT_DEVELOPER_KEY_HASH={developer_hash}")
        self.stdout.write("")
        self.stdout.write(self.style.WARNING("=== LLAVE DEL DESARROLLADOR (la que escribe en la app) ==="))
        self.stdout.write(self.style.SUCCESS(developer_key))
        self.stdout.write("")
        self.stdout.write(
            "La llave no se guarda en el servidor, solo su hash. Puede cambiarla cuando quiera con "
            "--solo-llave. No cambie AUDIT_LOG_KEY una vez que la bitácora tenga registros."
        )