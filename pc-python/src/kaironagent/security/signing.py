"""
KaironAgent HMAC-SHA256 İmza ve Replay Saldırısı Doğrulama Modülü
Protokol: sig = HMAC_SHA256(secret, kind|nonce|ts|utterance|ref_id)
"""

import hmac
import hashlib
import time
import sqlite3
from pathlib import Path
from typing import Tuple, Optional
from ..cloud.models import Command

class SigningVerifier:
    def __init__(self, secret: str, window_seconds: int = 90, db_path: Optional[Path] = None):
        self.secret = secret.encode("utf-8") if isinstance(secret, str) else secret
        self.window_seconds = window_seconds

        if db_path is None:
            # Varsayılan SQLite veri tabanı
            app_dir = Path.home() / "AppData" / "Local" / "KaironAgent"
            app_dir.mkdir(parents=True, exist_ok=True)
            self.db_path = app_dir / "nonces.sqlite"
        else:
            self.db_path = db_path

        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS seen_nonces (
                    nonce TEXT PRIMARY KEY,
                    ts INTEGER NOT NULL
                )
            """)
            conn.commit()

    def _purge_old_nonces(self, now: int):
        cutoff = now - 86400  # 24 saatten eski nonceları temizle
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("DELETE FROM seen_nonces WHERE ts < ?", (cutoff,))
            conn.commit()

    def _record_nonce(self, nonce: str, ts: int) -> bool:
        """Nonce daha önce kaydedilmemişse True döner, zaten varsa False (Replay)."""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("INSERT INTO seen_nonces (nonce, ts) VALUES (?, ?)", (nonce, ts))
                conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False

    @staticmethod
    def compute_signature(secret: str, kind: str, nonce: str, ts: int, utterance: str, ref_id: Optional[str] = None) -> str:
        """Robotun da kullandığı imza hesaplama fonksiyonu."""
        ref_str = str(ref_id) if ref_id else ""
        payload = f"{kind}|{nonce}|{ts}|{utterance}|{ref_str}".encode("utf-8")
        secret_bytes = secret.encode("utf-8") if isinstance(secret, str) else secret
        return hmac.new(secret_bytes, payload, hashlib.sha256).hexdigest().lower()

    def verify(self, cmd: Command) -> Tuple[bool, str]:
        """
        Gelen komutu doğrular:
        1. HMAC sırrı mevcut mu?
        2. Zaman penceresi (ts farkı <= window_seconds)
        3. Nonce tekrarı kontrolü (Replay Guard)
        4. Sabit zamanlı HMAC karşılaştırması
        """
        if not self.secret:
            return False, "PC tarafında HMAC gizli anahtarı tanımlı değil"

        now = int(time.time())
        self._purge_old_nonces(now)

        # 1. Zaman penceresi kontrolü
        ts_diff = abs(now - cmd.ts)
        if ts_diff > self.window_seconds:
            return False, f"Zaman damgası pencere dışı: {ts_diff}s > {self.window_seconds}s"

        # 2. Nonce kontrolü (Tekrar saldırısı koruması)
        if not self._record_nonce(cmd.nonce, cmd.ts):
            return False, f"Tekrar saldırısı engellendi: Nonce '{cmd.nonce}' daha önce kullanılmış"

        # 3. İmzayı hesapla ve doğrula
        ref_str = str(cmd.ref_id) if cmd.ref_id else ""
        expected_sig = self.compute_signature(
            secret=self.secret.decode("utf-8") if isinstance(self.secret, bytes) else self.secret,
            kind=str(cmd.kind.value if hasattr(cmd.kind, "value") else cmd.kind),
            nonce=cmd.nonce,
            ts=cmd.ts,
            utterance=cmd.utterance,
            ref_id=ref_str
        )

        if not hmac.compare_digest(expected_sig.lower(), cmd.sig.lower()):
            return False, "HMAC imzası geçersiz veya veri değiştirilmiş"

        return True, "Doğrulama başarılı"
