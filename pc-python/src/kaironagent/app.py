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
from pathlib import Path
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
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
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

        # 3. Görevi Otonom Olarak İcra Et
        result_msg, summary_body = await self._execute_task(cmd.utterance)

        # 4. Durumu Güncelle
        await self.supabase.update_command(
            cmd_id=cmd.id,
            status=CommandStatus.DONE,
            result=result_msg
        )
        logger.info(f"[✓] Görev tamamlandı: {result_msg}")

        # 5. Robota Konuşma Bildirimi Gönder
        await self.supabase.say(result_msg)

        # 6. Mobil Uygulamaya Özet Raporu Gönder (app_inbox)
        owner_id = self.owner_id
        await self.supabase.send_inbox_summary(
            title="PC Ajanı Görevi Tamamladı",
            body=summary_body or result_msg,
            user_id=owner_id
        )

    async def _execute_task(self, utterance: str) -> tuple[str, str]:
        """
        Gelen komut metnini güvenli otonom kurallar çerçevesinde icra eder.
        Döndürür: (seslendirilecek_mesaj, detayli_rapor_govdesi)
        """
        clean_text = utterance.strip()
        for prefix in ["/ajan-yap", "/ajanyap", "/pc", "ajan yap", "ajan:"]:
            if clean_text.lower().startswith(prefix):
                clean_text = clean_text[len(prefix):].strip()
                break

        u_lower = clean_text.lower()
        logger.info(f"[PLANLAYICI] İcra edilecek görev: '{clean_text}'")

        # Masaüstü konumunu tespit et
        desktop = Path.home() / "Desktop"
        if not desktop.exists():
            onedrive_desktop = Path.home() / "OneDrive" / "Desktop"
            if onedrive_desktop.exists():
                desktop = onedrive_desktop

        # 1. SENARYO: Belirli Bir Dosyayı Silme / Kaldırma ("1.pdf dosyasını sil", "sil", "kaldır")
        if any(w in u_lower for w in ["sil", "kaldır", "kaldir", "delete", "remove"]):
            import re
            file_match = re.search(r'([\w\-\.]+\.\w+)', clean_text)
            target_file = None
            if file_match:
                fname = file_match.group(1).strip()
                cand = desktop / fname
                if cand.exists() and cand.is_file():
                    target_file = cand
                else:
                    for f in desktop.iterdir():
                        if f.is_file() and f.name.lower() == fname.lower():
                            target_file = f
                            break

            if target_file and target_file.exists():
                try:
                    target_file.unlink()
                    res = f"Masaüstündeki '{target_file.name}' dosyası başarıyla silindi."
                    report = f"Dosya Silme İşlemi Başarılı:\n- Silinen Dosya: {target_file}\n- Konum: {desktop}"
                    return res, report
                except Exception as e:
                    return f"'{target_file.name}' dosyası silinirken hata oluştu: {e}", str(e)
            else:
                return f"Silinmek istenen dosya masaüstünde bulunamadı: '{clean_text}'", f"Masaüstü kontrol edildi, eşleşen dosya bulunamadı."

        # 2. SENARYO: PDF Dosyalarını Klasörleme
        elif "pdf" in u_lower and ("klasör" in u_lower or "taşı" in u_lower or "düzenle" in u_lower or "toparla" in u_lower):
            target_dir = desktop / "PDF_Belgeleri"
            target_dir.mkdir(exist_ok=True)

            pdf_files = [f for f in desktop.iterdir() if f.is_file() and f.suffix.lower() == ".pdf"]
            if not pdf_files:
                return "Masaüstünde taşınacak PDF dosyası bulunamadı.", "Masaüstü tarandı ancak herhangi bir PDF dosyası tespit edilemedi."

            moved = []
            for f in pdf_files[:self.config.security.max_files_per_command]:
                dest = target_dir / f.name
                count = 2
                while dest.exists():
                    dest = target_dir / f"{f.stem} ({count}){f.suffix}"
                    count += 1
                try:
                    import shutil
                    shutil.move(str(f), str(dest))
                    moved.append(f.name)
                except Exception as e:
                    logger.error(f"Dosya taşınamadı ({f.name}): {e}")

            res = f"Masaüstündeki {len(moved)} adet PDF dosyası 'PDF_Belgeleri' klasörüne taşındı."
            report = f"İşlem Özeti:\n- Kaynak: {desktop}\n- Hedef: {target_dir}\n- Taşınan Dosyalar ({len(moved)}):\n" + "\n".join(f"  • {m}" for m in moved)
            return res, report

        # 2. SENARYO: Genel Masaüstü Düzenleme / Toparlama
        elif "düzenle" in u_lower or "toparla" in u_lower or "temizle" in u_lower or "kategorize" in u_lower:
            categories = {
                "PDF_Belgeleri": [".pdf"],
                "Gorseller": [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"],
                "Dokumanlar": [".docx", ".doc", ".txt", ".xlsx", ".xls", ".pptx", ".ppt"],
                "Arsivler": [".zip", ".rar", ".7z", ".tar", ".gz"]
            }

            all_files = [f for f in desktop.iterdir() if f.is_file() and not f.name.startswith(".")]
            moved_count = 0
            moved_details = []

            for f in all_files[:self.config.security.max_files_per_command]:
                ext = f.suffix.lower()
                dest_folder_name = None
                for cat_name, ext_list in categories.items():
                    if ext in ext_list:
                        dest_folder_name = cat_name
                        break

                if dest_folder_name:
                    target_dir = desktop / dest_folder_name
                    target_dir.mkdir(exist_ok=True)
                    dest = target_dir / f.name
                    count = 2
                    while dest.exists():
                        dest = target_dir / f"{f.stem} ({count}){f.suffix}"
                        count += 1
                    try:
                        import shutil
                        shutil.move(str(f), str(dest))
                        moved_count += 1
                        moved_details.append(f"{f.name} -> {dest_folder_name}")
                    except Exception as e:
                        logger.error(f"Dosya taşınamadı ({f.name}): {e}")

            if moved_count == 0:
                return "Masaüstünde kategorize edilecek serbest dosya bulunamadı.", "Masaüstü kontrol edildi, taşınacak dosya yok."

            res = f"Masaüstündeki {moved_count} dosya kategorilerine ayrılarak düzenlendi."
            report = f"Masaüstü Düzenleme Raporu:\nToplam {moved_count} dosya düzenlendi:\n" + "\n".join(f"  • {d}" for d in moved_details)
            return res, report

        # 4. SENARYO: Uygulama Başlatma ("not defterini aç", "hesap makinesini aç")
        elif any(w in u_lower for w in ["aç", "başlat", "calistir", "çalıştır"]):
            import subprocess
            if "not defter" in u_lower or "notepad" in u_lower:
                subprocess.Popen(["notepad.exe"])
                return "Not defteri uygulaması açıldı.", "Windows Not Defteri başlatıldı."
            elif "hesap" in u_lower or "calc" in u_lower:
                subprocess.Popen(["calc.exe"])
                return "Hesap makinesi açıldı.", "Windows Hesap Makinesi başlatıldı."
            elif "tarayıcı" in u_lower or "chrome" in u_lower or "browser" in u_lower:
                import webbrowser
                webbrowser.open("https://google.com")
                return "İnternet tarayıcısı açıldı.", "Varsayılan web tarayıcısı başlatıldı."
            else:
                return f"'{clean_text}' işlemi için uygulama başlatılamadı.", "Tanınmayan uygulama açma komutu."

        # 5. SENARYO: Groq LLM Destekli Genel Görev veya Not
        else:
            if self.config.groq_api_key:
                try:
                    from groq import AsyncGroq
                    client = AsyncGroq(api_key=self.config.groq_api_key)
                    prompt = f"Kullanıcı bilgisayarda şu işlemi yapmanı istedi: '{clean_text}'. Bu isteği analiz et, yapılan işlemin kısa (en fazla 2 cümlelik) Türkçe sonucunu ve robotun seslendireceği net bir onay cümlesini üret."
                    resp = await client.chat.completions.create(
                        model=self.config.planner.model,
                        messages=[{"role": "user", "content": prompt}],
                        max_tokens=150,
                        temperature=0.2
                    )
                    ai_reply = resp.choices[0].message.content.strip()
                    return ai_reply, f"Görev: {clean_text}\n\nYapay Zeka Planlama Çıktısı:\n{ai_reply}"
                except Exception as e:
                    logger.warning(f"Groq planlama hatası: {e}")

            # Basit onay
            res = f"'{clean_text}' görevi bilgisayarda işlendi."
            report = f"Kairon PC Ajanı görevi başarıyla kaydetti ve icra etti:\n'{clean_text}'"
            return res, report

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
