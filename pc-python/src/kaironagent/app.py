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
import json
import re
from pathlib import Path
from typing import Optional, Any

from .config import load_config, AppConfig
from .cloud.supabase import SupabaseClient
from .cloud.models import Command, CommandStatus
from .security.signing import SigningVerifier
from .ui.pairing_dialog import PairingHelper
from .tools import (
    AGENT_TOOLS,
    dispatch_tool,
    tool_list_files,
    tool_create_file,
    tool_create_folder,
    tool_delete_file,
    tool_organize_files,
    tool_open_app,
    resolve_folder
)

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
        Gelen komut metnini otonom LLM Planlayıcı ve gerçek Windows araçlarıyla icra eder.
        Döndürür: (seslendirilecek_mesaj, detayli_rapor_govdesi)
        """
        clean_text = utterance.strip()
        for prefix in ["/ajan-yap", "/ajanyap", "/pc", "ajan yap", "ajan:"]:
            if clean_text.lower().startswith(prefix):
                clean_text = clean_text[len(prefix):].strip()
                break

        u_lower = clean_text.lower()
        logger.info(f"[PLANLAYICI] İcra edilecek görev: '{clean_text}'")

        # 1. Groq LLM + Tool Calling Motoru (Eğer anahtar varsa)
        if self.config.groq_api_key:
            try:
                from groq import AsyncGroq
                client = AsyncGroq(api_key=self.config.groq_api_key)

                system_prompt = (
                    "Sen Windows bilgisayar üzerinde otonom çalışan ve Kairon robotuna bağlı Kairon PC Ajanısın.\n"
                    "Kullanıcının masaüstü, dosyalar, klasörler ve bilgisayar ile ilgili görevlerini yerine getirmek için elindeki ARAÇLARI (tools) KULLAN.\n"
                    "Önemli Kurallar:\n"
                    "1. Dosya oluşturma, listeleme, silme, okuma, düzenleme gibi işlemleri MUTLAKA ilgili aracı çağırarak yap.\n"
                    "2. Asla aracı çağırmadan 'oluşturdum', 'sildim' veya 'dosya var' gibi uydurma cevaplar verme.\n"
                    "3. Kullanıcı 'kaç tane ... var' veya 'ne var' dediğinde list_files aracını çağırıp sonucu incele.\n"
                    "4. Robotun seslendirmesi için son cevabın net, kısa ve Türkçe olsun. Markdown madde işareti (*, #, -) ve emoji kullanma."
                )

                messages = [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": clean_text}
                ]

                executed_tools_log = []

                # Çok adımlı araç yürütme döngüsü (En fazla 4 adım)
                for step in range(4):
                    resp = await client.chat.completions.create(
                        model=self.config.planner.model,
                        messages=messages,
                        tools=AGENT_TOOLS,
                        tool_choice="auto",
                        max_tokens=300,
                        temperature=0.1
                    )
                    assistant_msg = resp.choices[0].message
                    messages.append(assistant_msg)

                    if not assistant_msg.tool_calls:
                        # Araç çağrısı yok, nihai cevap üretildi
                        final_reply = (assistant_msg.content or "").strip()
                        # Markdown temizliği (TTS için)
                        clean_say = re.sub(r'[*#_`~>]', '', final_reply).strip()
                        clean_say = " ".join(clean_say.split())

                        report_parts = [f"Görev: {clean_text}"]
                        if executed_tools_log:
                            report_parts.append("\nYürütülen Sistem Araçları:")
                            for t_log in executed_tools_log:
                                report_parts.append(f"  • {t_log}")
                        report_parts.append(f"\nSonuç:\n{final_reply}")

                        return clean_say, "\n".join(report_parts)

                    # Araç çağrılarını icra et
                    for tc in assistant_msg.tool_calls:
                        fn_name = tc.function.name
                        try:
                            fn_args = json.loads(tc.function.arguments) if tc.function.arguments else {}
                        except Exception:
                            fn_args = {}

                        logger.info(f"[ARAÇ ÇAĞRISI] {fn_name}({fn_args})")
                        tool_res = dispatch_tool(fn_name, fn_args)
                        status_str = tool_res.get("message") or tool_res.get("status") or "Tamamlandı"
                        logger.info(f"[ARAÇ SONUCU] {fn_name} -> {status_str}")

                        executed_tools_log.append(f"{fn_name}: {status_str}")

                        messages.append({
                            "role": "tool",
                            "tool_call_id": tc.id,
                            "content": json.dumps(tool_res, ensure_ascii=False)
                        })

            except Exception as e:
                logger.warning(f"Groq araç yürütme hatası, yerel kurallara geçiliyor: {e}")

        # 2. Yerel Kural Tabanlı Güvenli İcra (Fallback)
        # 1) Dosya Listeleme / Sayma (kaç tane, listele, göster)
        if any(w in u_lower for w in ["kaç", "kac", "say", "listele", "neler var", "ne var"]):
            ext = "*"
            if "pdf" in u_lower:
                ext = ".pdf"
            elif "txt" in u_lower or "metin" in u_lower:
                ext = ".txt"
            elif "resim" in u_lower or "görsel" in u_lower:
                ext = ".png"
            res = tool_list_files(folder="desktop", extension=ext)
            count = res.get("total_count", 0)
            speech = f"Masaüstünde {count} adet {ext if ext != '*' else ''} dosya bulunuyor."
            report = f"Masaüstü Dosya Listeleme:\nToplam: {count}\nDosyalar:\n" + "\n".join(f"  • {f}" for f in res.get("files", []))
            return speech, report

        # 2) Dosya Silme (sil, kaldır)
        if any(w in u_lower for w in ["sil", "kaldır", "kaldir", "delete", "remove"]):
            file_match = re.search(r'([\w\-\.]+\.\w+)', clean_text)
            fname = file_match.group(1).strip() if file_match else ""
            if not fname:
                words = clean_text.split()
                for w in words:
                    if "." in w and len(w) > 3:
                        fname = w
                        break
            if fname:
                res = tool_delete_file(filename=fname, folder="desktop")
                if res.get("status") == "ok":
                    return f"Masaüstündeki {fname} dosyası başarıyla silindi.", str(res)
                else:
                    return f"{fname} dosyası masaüstünde bulunamadı.", str(res)

        # 3) Dosya / Klasör Oluşturma (oluştur, yarat, kaydet)
        if any(w in u_lower for w in ["oluştur", "olustur", "yarat", "yeni dosya", "metin dosyası", "text dosyası"]):
            if "klasör" in u_lower or "folder" in u_lower:
                match = re.search(r'["\']([^"\']+)["\']', clean_text) or re.search(r'(\b\w+\b)\s+(adında|isimli|adli|adlı)', clean_text)
                fol_name = match.group(1) if match else "Yeni Klasör"
                res = tool_create_folder(folder_name=fol_name, parent_folder="desktop")
                return f"Masaüstünde '{fol_name}' klasörü oluşturuldu.", str(res)
            else:
                match = re.search(r'["\']([^"\']+)["\']', clean_text) or re.search(r'([\w\-]+)\s+(adında|isimli|adli|adlı)', clean_text)
                fname = match.group(1) if match else "Kairon-Not"
                content = ""
                content_match = re.search(r'içine\s+["\']?([^"\']+)["\']?\s+(yaz|kaydet)', clean_text, re.IGNORECASE)
                if content_match:
                    content = content_match.group(1).strip()
                res = tool_create_file(filename=fname, content=content, folder="desktop")
                return f"Masaüstünde '{fname}' dosyası oluşturuldu.", str(res)

        # 4) Dosyaları Düzenleme / Toparlama
        if any(w in u_lower for w in ["düzenle", "duzenle", "toparla", "temizle", "kategorize"]):
            res = tool_organize_files(pattern="all", folder="desktop")
            return res.get("message", "Masaüstü düzenlendi."), str(res)

        # 5) Uygulama Başlatma
        if any(w in u_lower for w in ["not defter", "notepad", "hesap makinesi", "calc", "tarayıcı", "chrome"]):
            res = tool_open_app(clean_text)
            return res.get("message", "Uygulama başlatıldı."), str(res)

        # Genel Yedek
        return f"'{clean_text}' görevi için uygun işlem belirlendi.", f"Görev: {clean_text}"

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
