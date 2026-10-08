"""
Bitácora confidencial de SITUR-SMART (móvil).

Cada acción de los usuarios se guarda como una línea CIFRADA en un archivo
de texto (no en la base de datos), un archivo por mes:

    <AUDIT_LOG_DIR>/bitacora-AAAA-MM.log

- El cifrado usa Fernet (AES-128 + HMAC-SHA256) con la clave AUDIT_LOG_KEY,
  que vive solo en las variables de entorno del servidor. El administrador de
  la base de datos no ve el archivo, y aunque lo copiara no podría leerlo.
- Solo se puede consultar desde el sistema presentando la llave única del
  desarrollador, que se compara con AUDIT_DEVELOPER_KEY_HASH (SHA-256). La
  llave en sí no se guarda en ningún lado del servidor.
- La fecha y la hora se registran en hora de Bolivia (America/La_Paz, UTC-4).
"""

import hashlib
import hmac
import json
import logging
import threading
import uuid
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings

logger = logging.getLogger(__name__)

BOLIVIA_TZ = ZoneInfo("America/La_Paz")

_write_lock = threading.Lock()
_warned_missing_key = False


# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------


class SecureLogNotConfigured(Exception):
    """Faltan AUDIT_LOG_KEY o AUDIT_DEVELOPER_KEY_HASH en el entorno."""


def _fernet() -> Fernet:
    key = getattr(settings, "AUDIT_LOG_KEY", "")
    if not key:
        raise SecureLogNotConfigured("No se definió AUDIT_LOG_KEY.")
    return Fernet(key.encode() if isinstance(key, str) else key)


def _log_dir() -> Path:
    path = Path(settings.AUDIT_LOG_DIR)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _file_for(day: date) -> Path:
    return _log_dir() / f"bitacora-{day:%Y-%m}.log"


def is_configured() -> bool:
    return bool(getattr(settings, "AUDIT_LOG_KEY", "")) and bool(
        getattr(settings, "AUDIT_DEVELOPER_KEY_HASH", "")
    )


def verify_developer_key(raw_key: str) -> bool:
    """Compara la llave recibida con el hash configurado, en tiempo constante."""
    expected = getattr(settings, "AUDIT_DEVELOPER_KEY_HASH", "")
    if not expected or not raw_key:
        return False
    received = hashlib.sha256(raw_key.encode("utf-8")).hexdigest()
    return hmac.compare_digest(received, expected.strip().lower())


# ---------------------------------------------------------------------------
# Escritura
# ---------------------------------------------------------------------------


def client_ip(request) -> str | None:
    """IP real del cliente (detrás del proxy de Railway llega en X-Forwarded-For)."""
    if request is None:
        return None
    meta = getattr(request, "META", {})
    forwarded = meta.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",", 1)[0].strip()
    return meta.get("REMOTE_ADDR")


def now_bolivia() -> datetime:
    return datetime.now(BOLIVIA_TZ)


def write(*, request=None, user=None, action: str, email: str | None = None, status: int | None = None) -> None:
    """
    Agrega una línea cifrada a la bitácora. Nunca interrumpe la petición:
    si algo falla, solo se avisa en la consola del servidor.
    """
    global _warned_missing_key
    try:
        fernet = _fernet()
    except SecureLogNotConfigured:
        if not _warned_missing_key:
            logger.warning("Bitácora confidencial desactivada: falta AUDIT_LOG_KEY.")
            _warned_missing_key = True
        return

    try:
        moment = now_bolivia()
        authenticated = user is not None and getattr(user, "is_authenticated", False)
        entry = {
            "id": uuid.uuid4().hex[:12],
            "fecha_hora": moment.isoformat(timespec="seconds"),
            "fecha": moment.strftime("%d/%m/%Y"),
            "hora": moment.strftime("%H:%M:%S"),
            "ip": client_ip(request),
            "usuario_id": user.pk if authenticated else None,
            "usuario": user.get_full_name() if authenticated else None,
            "correo": user.email if authenticated else email,
            "accion": action,
            "metodo": getattr(request, "method", None),
            "ruta": getattr(request, "path", None),
            "estado": status,
        }
        token = fernet.encrypt(json.dumps(entry, ensure_ascii=False).encode("utf-8"))
        with _write_lock, open(_file_for(moment.date()), "ab") as handle:
            handle.write(token + b"\n")
    except Exception:  # noqa: BLE001 - la bitácora no debe romper el sistema
        logger.exception("No se pudo escribir en la bitácora confidencial.")


# ---------------------------------------------------------------------------
# Lectura (solo con la llave del desarrollador)
# ---------------------------------------------------------------------------


def _months_between(start: date, end: date):
    year, month = start.year, start.month
    while (year, month) <= (end.year, end.month):
        yield date(year, month, 1)
        month += 1
        if month > 12:
            year, month = year + 1, 1


def read(
    *,
    date_from: date | None = None,
    date_to: date | None = None,
    user_text: str = "",
    action_text: str = "",
    ip_text: str = "",
    limit: int = 300,
) -> tuple[list[dict], int]:
    """
    Descifra y filtra la bitácora. Devuelve (registros más recientes primero,
    total de coincidencias). Las fechas se interpretan en hora de Bolivia.
    """
    fernet = _fernet()
    today = now_bolivia().date()
    end = date_to or today

    if date_from is not None:
        start = date_from
    else:
        existing = sorted(_log_dir().glob("bitacora-*.log"))
        if not existing:
            return [], 0
        first = existing[0].stem.replace("bitacora-", "")
        start = date(int(first[:4]), int(first[5:7]), 1)

    user_text = user_text.strip().lower()
    action_text = action_text.strip().lower()
    ip_text = ip_text.strip()

    matches: list[dict] = []
    for month in _months_between(start, end):
        path = _file_for(month)
        if not path.exists():
            continue
        with open(path, "rb") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(fernet.decrypt(line).decode("utf-8"))
                except (InvalidToken, ValueError):
                    continue

                day = datetime.fromisoformat(entry["fecha_hora"]).date()
                if day < start or day > end:
                    continue
                if user_text:
                    haystack = f"{entry.get('usuario') or ''} {entry.get('correo') or ''}".lower()
                    if user_text not in haystack:
                        continue
                if action_text and action_text not in (entry.get("accion") or "").lower():
                    continue
                if ip_text and ip_text not in (entry.get("ip") or ""):
                    continue
                matches.append(entry)

    matches.sort(key=lambda item: item["fecha_hora"], reverse=True)
    return matches[:limit], len(matches)