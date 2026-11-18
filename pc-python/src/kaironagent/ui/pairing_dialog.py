"""
KaironAgent PC Eşleştirme Penceresi (WhatsApp Web / QR Modeli)
Mobil uygulamadan tek seferlik eşleştirme için 6 haneli kod gösterir ve doğrular.
"""

import random
import asyncio
import logging
import tkinter as tk
from typing import Optional
from ..cloud.supabase import SupabaseClient
from ..config import get_secret

logger = logging.getLogger("kaironagent.pairing")

class PairingHelper:
    def __init__(self, supabase: SupabaseClient):
        self.supabase = supabase

    async def ensure_paired(self) -> Optional[str]:
        """PC'nin bir kullanıcı hesabına bağlı olup olmadığını doğrular, bağlı değilse eşleştirme başlatır."""
        # 1. Mevcut sahipliği kontrol et
        owner_id = await self.supabase.get_pc_owner()
        if owner_id:
            logger.info(f"[✓] PC Ajanı zaten yetkilendirilmiş hesaba bağlı (owner_id: {owner_id[:8]}...)")
            return owner_id

        # 2. Yeni 6 haneli rastgele PIN üret
        pin_code = str(random.randint(100000, 999999))
        logger.info("=" * 60)
        logger.info("  [!] BU BİLGİSAYAR HENÜZ BİR KULLANICI HESABINA BAĞLI DEĞİL")
        logger.info(f"  --> Mobil uygulamayı açın ve Eşleştirme Kodu olarak şunu girin:")
        logger.info(f"                  [  {pin_code}  ]")
        logger.info("=" * 60)

        # 3. Supabase'e geçici eşleşme oturumu aç
        ok = await self.supabase.create_pairing_session(pin_code)
        if not ok:
            logger.warning("Eşleşme oturumu veritabanına kaydedilemedi.")

        # 4. Arayüzü aç ve onay bekle
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
        """Kullanıcının telefondan kodu girmesini 5 dakika boyunca asenkron olarak bekler."""
        # Tkinter penceresini arka plan thread'de veya basit pencere olarak gösterebiliriz
        for _ in range(150):  # 150 * 2sn = 300 saniye (5 dakika)
            claimed_by = await self.supabase.check_pairing_status(code)
            if claimed_by:
                return claimed_by
            await asyncio.sleep(2)
        return None
