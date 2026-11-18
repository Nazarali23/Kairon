"""
KaironAgent PC Eşleştirme Yardımcısı
Mobil uygulamadan tek seferlik eşleştirme için 6 haneli PIN ve QR oturumu oluşturur ve doğrular.
"""

import random
import asyncio
import logging
from typing import Optional, Callable
from ..cloud.supabase import SupabaseClient

logger = logging.getLogger("kaironagent.pairing")

class PairingHelper:
    def __init__(self, supabase: SupabaseClient, on_pin_callback: Optional[Callable[[str], None]] = None):
        self.supabase = supabase
        self.on_pin_callback = on_pin_callback

    async def ensure_paired(self) -> Optional[str]:
        """PC'nin bir kullanıcı hesabına bağlı olup olmadığını doğrular, bağlı değilse eşleştirme başlatır."""
        # 1. Mevcut sahipliği kontrol et
        owner_id = await self.supabase.get_pc_owner()
        if owner_id:
            logger.info(f"[✓] PC Ajanı hesaba bağlı (owner_id: {owner_id[:8]}...)")
            return owner_id

        # 2. Yeni 6 haneli rastgele PIN üret
        pin_code = str(random.randint(100000, 999999))
        logger.info("=" * 60)
        logger.info("  [!] BU BİLGİSAYAR HENÜZ BİR KULLANICI HESABINA BAĞLI DEĞİL")
        logger.info(f"  --> Mobil uygulamayı açın ve Eşleştirme Kodu olarak şunu girin:")
        logger.info(f"                  [  {pin_code}  ]")
        logger.info("=" * 60)

        if self.on_pin_callback:
            self.on_pin_callback(pin_code)

        # 3. Supabase'e geçici eşleşme oturumu aç
        ok = await self.supabase.create_pairing_session(pin_code)
        if not ok:
            logger.warning("Eşleşme oturumu veritabanına kaydedilemedi.")

        # 4. Onay bekle
        owner_id = await self._wait_for_pairing(pin_code)
        if owner_id:
            await self.supabase.set_pc_owner(owner_id)
            logger.info(f"[✓] Eşleştirme başarıyla tamamlandı! Sahip: {owner_id}")
            try:
                import keyring
                keyring.set_password("KaironAgent", "owner_id", owner_id)
            except Exception:
                pass
            return owner_id

        return None

    async def _wait_for_pairing(self, code: str) -> Optional[str]:
        """Kullanıcının telefondan kodu girmesini 15 dakika boyunca asenkron olarak bekler."""
        for _ in range(450):  # 450 * 2sn = 900 saniye (15 dakika)
            claimed_by = await self.supabase.check_pairing_status(code)
            if claimed_by:
                return claimed_by
            await asyncio.sleep(2)
        return None
