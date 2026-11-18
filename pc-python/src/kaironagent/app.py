"""
KaironAgent Ana Uygulama Döngüsü
- Modern GUI arayüzü (Tkinter + QR + Canlı Günlük).
- Supabase ile periyodik heartbeat gönderir (pc_agent_state).
- pc_commands tablosunu yoklar, komutları doğrular ve durum makinesini işletir.
- Sistem tepsisi ve masaüstü arayüzü sunar.
"""

import sys
import signal
import asyncio
import logging
import threading
from typing import Optional, Any

from .config import load_config, AppConfig
from .cloud.supabase import SupabaseClient
from .cloud.models import Command, CommandStatus
from .security.signing import SigningVerifier
from .ui.pairing_dialog import PairingHelper

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("kaironagent")

class KaironAgentApp:
    def __init__(self, config: Optional[AppConfig] = None):
        self.config = config or load_config()
        self.running = False
        self.owner_id: Optional[str] = None
        self.gui: Optional[Any] = None
        self.supabase = SupabaseClient(
            supabase_url=self.config.cloud.supabase_url,
            service_role_key=self.config.service_role_key
        )
        self.verifier = SigningVerifier(
            secret=self.config.hmac_secret,
            window_seconds=self.config.security.timestamp_window_s
        )

    async def start(self):
        self.running = True
        logger.info("=" * 60)
        logger.info("KaironAgent (PC) başlatılıyor...")
        logger.info(f"Supabase URL: {self.config.cloud.supabase_url}")
        logger.info(f"Ekran Ölçeği: %{int(self.config.cursor.screen_scale * 100)}")
        logger.info(f"Otomatik Onay Dosya Eşiği: {self.config.security.auto_confirm_max_files}")
        logger.info(f"Planlayıcı Model: {self.config.planner.model}")
        logger.info("=" * 60)

        # Cihaz Eşleştirme ve Sahiplik Doğrulaması (Device Claiming)
        def on_pin_generated(pin_code: str):
            if self.gui:
                self.gui.update_pairing_state(is_paired=False, pin_code=pin_code)

        pairing_helper = PairingHelper(self.supabase, on_pin_callback=on_pin_generated)
        self.owner_id = await pairing_helper.ensure_paired()

        if self.gui:
            self.gui.update_pairing_state(is_paired=bool(self.owner_id), owner_id=self.owner_id or "")

        # İlk heartbeat
        hb_ok = await self.supabase.heartbeat(online=True, busy=False)
        if self.gui:
            self.gui.set_online_status(hb_ok)

        # Arka plan görevleri
        heartbeat_task = asyncio.create_task(self._heartbeat_loop())
        poll_task = asyncio.create_task(self._poll_loop())

        try:
            await asyncio.gather(heartbeat_task, poll_task)
        except asyncio.CancelledError:
            pass
        finally:
            logger.info("Ajan kapatılıyor, durum güncelleniyor...")
            await self.supabase.heartbeat(online=False, busy=False)
            if self.gui:
                self.gui.set_online_status(False)

    def stop(self):
        self.running = False

    async def _heartbeat_loop(self):
        """pc_agent_state tablosuna 15 saniyede bir canlılık bilgisi atar."""
        while self.running:
            try:
                ok = await self.supabase.heartbeat(online=True, busy=False)
                if self.gui:
                    self.gui.set_online_status(ok)
            except Exception as e:
                logger.warning(f"Heartbeat hatası: {e}")
                if self.gui:
                    self.gui.set_online_status(False)
            await asyncio.sleep(self.config.cloud.heartbeat_s)

    async def _poll_loop(self):
        """pc_commands kuyruğunu periyodik olarak kontrol eder."""
        while self.running:
            sleep_interval = self.config.cloud.poll_idle_s

            try:
                pending_cmds = await self.supabase.fetch_pending(limit=3)
                if pending_cmds:
                    sleep_interval = self.config.cloud.poll_active_s
                    for cmd in pending_cmds:
                        await self._process_command(cmd)
            except Exception as e:
                logger.error(f"Komut yoklama hatası: {e}")

            await asyncio.sleep(sleep_interval)

    async def _process_command(self, cmd: Command):
        logger.info(f"[+] Yeni komut yakalandı: ID={cmd.id}, kind={cmd.kind}, utterance='{cmd.utterance}'")

        # 1. Atomik Sahiplenme (Claim)
        claimed = await self.supabase.claim(cmd.id)
        if not claimed:
            logger.info(f"Komut başka bir oturum tarafından alındı, atlanıyor: {cmd.id}")
            return

        # 2. HMAC ve Güvenlik Doğrulaması
        ok, reason = self.verifier.verify(cmd)
        if not ok:
            logger.warning(f"[-] Komut güvenlik kontrolünden geçemedi: {reason}")
            await self.supabase.update_command(
                cmd_id=cmd.id,
                status=CommandStatus.REJECTED,
                error=reason,
                result="Güvenlik doğrulaması başarısız oldu."
            )
            await self.supabase.say("Güvenlik doğrulaması başarısız oldu, işlem reddedildi.")
            return

        logger.info(f"[+] Güvenlik onayı başarılı: {cmd.id}")

        # V0 Aşamasında test amaçlı kabul ve onay
        result_msg = f"Komut başarıyla alındı: {cmd.utterance[:50]}"
        await self.supabase.update_command(
            cmd_id=cmd.id,
            status=CommandStatus.DONE,
            result=result_msg
        )
        logger.info(f"[✓] Komut tamamlandı: {result_msg}")
        await self.supabase.say("Bilgisayarda komut başarıyla işlendi.")

def main():
    is_headless = "--headless" in sys.argv

    app = KaironAgentApp()

    if is_headless:
        # CLI / Konsol Modu
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        def shutdown(sig, frame):
            logger.info(f"Sinyal alındı ({sig}), durduruluyor...")
            app.stop()
            for task in asyncio.all_tasks(loop):
                task.cancel()

        signal.signal(signal.SIGINT, shutdown)
        signal.signal(signal.SIGTERM, shutdown)

        try:
            loop.run_until_complete(app.start())
        except KeyboardInterrupt:
            pass
        finally:
            loop.close()
    else:
        # Görsel Masaüstü Uygulaması (GUI Modu)
        from .ui.main_window import AgentMainWindow

        gui = AgentMainWindow(app, on_close_callback=app.stop)
        app.gui = gui

        loop = asyncio.new_event_loop()

        def run_async():
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(app.start())
            except Exception as e:
                logger.error(f"Arka plan motor hatası: {e}")

        t = threading.Thread(target=run_async, daemon=True)
        t.start()

        try:
            gui.run()
        except KeyboardInterrupt:
            pass
        finally:
            app.stop()

if __name__ == "__main__":
    main()
