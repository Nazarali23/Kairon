"""
KaironAgent Modern Masaüstü Uygulama Arayüzü (GUI)
- Windows üzerinde modern koyu / siber tema ile çalışır.
- Canlı bağlantı durumu (Heartbeat) ve Supabase bilgilerini gösterir.
- QR Kod ve 6 haneli PIN ile mobil cihaz eşleştirme kartını sunar.
- Gerçek zamanlı konsol/görev günlüğü ve sistem tepsisi (System Tray) desteği içerir.
"""

import io
import queue
import logging
import threading
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Optional, Callable

from PIL import Image, ImageTk
import qrcode
import pystray

logger = logging.getLogger("kaironagent.ui")

class GuiLogHandler(logging.Handler):
    """Logging mesajlarını GUI terminaline thread-safe olarak aktaran handler."""
    def __init__(self, log_queue: queue.Queue):
        super().__init__()
        self.log_queue = log_queue

    def emit(self, record):
        try:
            msg = self.format(record)
            self.log_queue.put(msg)
        except Exception:
            pass

class AgentMainWindow:
    # Siber Renk Paleti
    BG_DARK = "#0B0F19"
    CARD_BG = "#131A26"
    CARD_BORDER = "#1F293D"
    ACCENT_CYAN = "#00E5FF"
    ACCENT_PURPLE = "#B388FF"
    GREEN_ONLINE = "#00E676"
    AMBER_WAITING = "#FFD600"
    RED_OFFLINE = "#FF5252"
    TEXT_WHITE = "#FFFFFF"
    TEXT_MUTED = "#8A9BA8"

    def __init__(self, app_instance, on_close_callback: Optional[Callable] = None):
        self.app = app_instance
        self.on_close_callback = on_close_callback
        self.log_queue = queue.Queue()

        self.root = tk.Tk()
        self.root.title("KAIRON AGENT - Windows Otonom Asistan Ajanı")
        self.root.geometry("680x760")
        self.root.minsize(580, 620)
        self.root.configure(bg=self.BG_DARK)

        # Durum Değişkenleri
        self.is_online = False
        self.is_paired = False
        self.owner_id = ""
        self.current_pin = ""
        self.qr_photo: Optional[ImageTk.PhotoImage] = None
        self.tray_icon = None

        # Log dinleyiciyi bağla
        self.log_handler = GuiLogHandler(self.log_queue)
        formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", datefmt="%H:%M:%S")
        self.log_handler.setFormatter(formatter)
        logging.getLogger().addHandler(self.log_handler)

        self._build_ui()
        self._setup_tray()

        # Tkinter olay döngüsü kuyruk kontrolü
        self.root.protocol("WM_DELETE_WINDOW", self.on_window_close)
        self.root.after(100, self._process_log_queue)

    def _build_ui(self):
        # 1. ÜST BAŞLIK VE CANLILIK KARTI
        header_card = tk.Frame(self.root, bg=self.CARD_BG, highlightbackground=self.CARD_BORDER, highlightthickness=1)
        header_card.pack(fill=tk.X, padx=16, pady=(16, 10))

        h_content = tk.Frame(header_card, bg=self.CARD_BG)
        h_content.pack(fill=tk.X, padx=16, pady=14)

        # Sol: Logo ve İsim
        title_box = tk.Frame(h_content, bg=self.CARD_BG)
        title_box.pack(side=tk.LEFT)

        lbl_app = tk.Label(
            title_box,
            text="🤖 KAIRON PC AGENT",
            font=("Segoe UI", 16, "bold"),
            fg=self.ACCENT_CYAN,
            bg=self.CARD_BG
        )
        lbl_app.pack(anchor="w")

        lbl_sub = tk.Label(
            title_box,
            text="Windows Otonom Sistem ve Belge Ajanı (v0.2.0)",
            font=("Segoe UI", 9),
            fg=self.TEXT_MUTED,
            bg=self.CARD_BG
        )
        lbl_sub.pack(anchor="w", pady=(2, 0))

        # Sağ: Durum Rozeti (Online / Eşleşme Bekliyor)
        self.status_badge = tk.Label(
            h_content,
            text="● BAŞLATILIYOR",
            font=("Segoe UI", 10, "bold"),
            fg=self.AMBER_WAITING,
            bg="#1F2836",
            padx=12,
            pady=6
        )
        self.status_badge.pack(side=tk.RIGHT)

        # Sistem Bilgi Çubuğu
        info_bar = tk.Frame(header_card, bg="#0E1420", padx=16, pady=6)
        info_bar.pack(fill=tk.X)

        scale_pct = int(self.app.config.cursor.screen_scale * 100)
        self.lbl_sysinfo = tk.Label(
            info_bar,
            text=f"Bilgisayar: {self.app.supabase.hostname}  |  Ekran Ölçeği: %{scale_pct} DPI  |  Model: {self.app.config.planner.model}",
            font=("Consolas", 8),
            fg=self.TEXT_MUTED,
            bg="#0E1420"
        )
        self.lbl_sysinfo.pack(side=tk.LEFT)

        # 2. EŞLEŞTİRME VE SAHİPLİK KARTI (QR & PIN)
        self.pair_card = tk.Frame(self.root, bg=self.CARD_BG, highlightbackground=self.CARD_BORDER, highlightthickness=1)
        self.pair_card.pack(fill=tk.X, padx=16, pady=6)

        self.pair_container = tk.Frame(self.pair_card, bg=self.CARD_BG, padx=16, pady=16)
        self.pair_container.pack(fill=tk.X)

        # Bu alan dinamik olarak güncellenir (_render_pairing_view)
        self._render_pairing_view()

        # 3. CANLI KONSOL VE AKTİVİTE GÜNLÜĞÜ
        terminal_card = tk.Frame(self.root, bg=self.CARD_BG, highlightbackground=self.CARD_BORDER, highlightthickness=1)
        terminal_card.pack(fill=tk.BOTH, expand=True, padx=16, pady=6)

        term_header = tk.Frame(terminal_card, bg=self.CARD_BG, padx=14, pady=10)
        term_header.pack(fill=tk.X)

        tk.Label(
            term_header,
            text="CANLI ETKİNLİK VE GÖREV GÜNLÜĞÜ",
            font=("Segoe UI", 10, "bold"),
            fg=self.TEXT_WHITE,
            bg=self.CARD_BG
        ).pack(side=tk.LEFT)

        btn_clear = tk.Button(
            term_header,
            text="Temizle",
            font=("Segoe UI", 8),
            fg=self.TEXT_MUTED,
            bg="#1B2433",
            activebackground="#26354A",
            activeforeground=self.TEXT_WHITE,
            relief=tk.FLAT,
            padx=8,
            pady=2,
            command=self._clear_logs
        )
        btn_clear.pack(side=tk.RIGHT)

        # Monospace Terminal Metin Kutusu
        term_body = tk.Frame(terminal_card, bg="#070A10")
        term_body.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        self.terminal_text = tk.Text(
            term_body,
            bg="#070A10",
            fg=self.ACCENT_CYAN,
            font=("Consolas", 9),
            insertbackground="white",
            selectbackground="#1E3A5F",
            relief=tk.FLAT,
            wrap=tk.WORD,
            state=tk.DISABLED
        )
        scrollbar = ttk.Scrollbar(term_body, orient=tk.VERTICAL, command=self.terminal_text.yview)
        self.terminal_text.configure(yscrollcommand=scrollbar.set)

        self.terminal_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Renkli tag'ler
        self.terminal_text.tag_config("info", foreground="#A0AEC0")
        self.terminal_text.tag_config("cyan", foreground=self.ACCENT_CYAN)
        self.terminal_text.tag_config("green", foreground=self.GREEN_ONLINE)
        self.terminal_text.tag_config("yellow", foreground=self.AMBER_WAITING)
        self.terminal_text.tag_config("red", foreground=self.RED_OFFLINE)

        # 4. ALT EYLEM VE KONTROL ÇUBUĞU
        footer = tk.Frame(self.root, bg=self.BG_DARK)
        footer.pack(fill=tk.X, padx=16, pady=(6, 16))

        btn_test = tk.Button(
            footer,
            text="⚡ Test Komutu Gönder",
            font=("Segoe UI", 9, "bold"),
            bg="#182232",
            fg=self.ACCENT_CYAN,
            relief=tk.FLAT,
            padx=12,
            pady=8,
            command=self._simulate_test_command
        )
        btn_test.pack(side=tk.LEFT)

        btn_minimize = tk.Button(
            footer,
            text="Tepsiye Küçült",
            font=("Segoe UI", 9),
            bg="#182232",
            fg=self.TEXT_WHITE,
            relief=tk.FLAT,
            padx=12,
            pady=8,
            command=self.hide_to_tray
        )
        btn_minimize.pack(side=tk.RIGHT, padx=(8, 0))

        btn_quit = tk.Button(
            footer,
            text="Ajanı Kapat",
            font=("Segoe UI", 9),
            bg="#2A1620",
            fg="#FF8A80",
            relief=tk.FLAT,
            padx=12,
            pady=8,
            command=self.on_window_close
        )
        btn_quit.pack(side=tk.RIGHT)

    def _render_pairing_view(self):
        # Önceki içeriği temizle
        for widget in self.pair_container.winfo_children():
            widget.destroy()

        if self.is_paired:
            # EŞLEŞMİŞ DURUM (Yeşil Onay)
            top_row = tk.Frame(self.pair_container, bg=self.CARD_BG)
            top_row.pack(fill=tk.X)

            icon_lbl = tk.Label(top_row, text="✓", font=("Segoe UI", 20, "bold"), fg=self.GREEN_ONLINE, bg=self.CARD_BG)
            icon_lbl.pack(side=tk.LEFT, padx=(0, 10))

            t_box = tk.Frame(top_row, bg=self.CARD_BG)
            t_box.pack(side=tk.LEFT, fill=tk.X, expand=True)

            tk.Label(
                t_box,
                text="BU BİLGİSAYAR HESABINIZA BAŞARIYLA BAĞLI",
                font=("Segoe UI", 11, "bold"),
                fg=self.GREEN_ONLINE,
                bg=self.CARD_BG
            ).pack(anchor="w")

            tk.Label(
                t_box,
                text=f"Yetkili Sahip UUID: {self.owner_id}",
                font=("Consolas", 9),
                fg=self.TEXT_MUTED,
                bg=self.CARD_BG
            ).pack(anchor="w", pady=(2, 0))

            tk.Label(
                self.pair_container,
                text="Kairon Robotu veya Mobil uygulamanız üzerinden verilen masaüstü görevleri güvenle dinleniyor.",
                font=("Segoe UI", 9),
                fg="#CBD5E0",
                bg=self.CARD_BG
            ).pack(anchor="w", pady=(8, 0))

        else:
            # EŞLEŞME BEKLENİYOR DURUMU (QR + PIN)
            main_pair = tk.Frame(self.pair_container, bg=self.CARD_BG)
            main_pair.pack(fill=tk.X)

            # Sol: QR Kod Görseli
            qr_frame = tk.Frame(main_pair, bg=self.CARD_BG, width=140, height=140)
            qr_frame.pack(side=tk.LEFT, padx=(0, 20))

            if self.current_pin:
                try:
                    qr = qrcode.QRCode(box_size=4, border=2)
                    qr.add_data(self.current_pin)
                    qr.make(fit=True)
                    img = qr.make_image(fill_color="black", back_color="white").resize((130, 130))
                    self.qr_photo = ImageTk.PhotoImage(img)
                    lbl_qr = tk.Label(qr_frame, image=self.qr_photo, bg="white")
                    lbl_qr.pack()
                except Exception as e:
                    logger.warning(f"QR kodu oluşturulamadı: {e}")
                    tk.Label(qr_frame, text="[QR]", fg="grey", bg=self.CARD_BG).pack()
            else:
                tk.Label(qr_frame, text="Yükleniyor...", fg=self.TEXT_MUTED, bg=self.CARD_BG).pack(pady=40)

            # Sağ: PIN ve Açıklama
            right_box = tk.Frame(main_pair, bg=self.CARD_BG)
            right_box.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

            tk.Label(
                right_box,
                text="MOBİL UYGULAMA İLE CİHAZI EŞLEŞTİRİN",
                font=("Segoe UI", 11, "bold"),
                fg=self.ACCENT_CYAN,
                bg=self.CARD_BG
            ).pack(anchor="w")

            tk.Label(
                right_box,
                text="Telefonunuzda 'Cihaz Eşleştir' sekmesini açın ve QR kodu kamerayla tarayın veya alttaki PIN kodunu girin:",
                font=("Segoe UI", 9),
                fg=self.TEXT_MUTED,
                bg=self.CARD_BG,
                wraplength=380,
                justify="left"
            ).pack(anchor="w", pady=(4, 8))

            pin_val = self.current_pin or "------"
            pin_spaced = "  ".join(pin_val)

            pin_box = tk.Frame(right_box, bg="#0E1624", padx=16, pady=8, highlightbackground=self.ACCENT_CYAN, highlightthickness=1)
            pin_box.pack(anchor="w")

            tk.Label(
                pin_box,
                text=pin_spaced,
                font=("Consolas", 18, "bold"),
                fg=self.ACCENT_CYAN,
                bg="#0E1624"
            ).pack()

            tk.Label(
                right_box,
                text="⏳ Eşleşme bekleniyor... (Oturum süresi: 15 dakika)",
                font=("Segoe UI", 8),
                fg=self.AMBER_WAITING,
                bg=self.CARD_BG
            ).pack(anchor="w", pady=(8, 0))

    def update_pairing_state(self, is_paired: bool, owner_id: str = "", pin_code: str = ""):
        """Ajanın eşleşme durumunu günceller ve arayüzü yeniler (Thread-safe)."""
        def _update():
            self.is_paired = is_paired
            self.owner_id = owner_id
            self.current_pin = pin_code
            if is_paired:
                self.status_badge.config(text="● ÇEVRİMİÇİ (BAĞLI)", fg=self.GREEN_ONLINE, bg="#0F2D1F")
            else:
                self.status_badge.config(text="● EŞLEŞME BEKLİYOR", fg=self.AMBER_WAITING, bg="#2D270F")
            self._render_pairing_view()

        self.root.after(0, _update)

    def set_online_status(self, online: bool):
        def _set():
            self.is_online = online
            if online:
                if self.is_paired:
                    self.status_badge.config(text="● ÇEVRİMİÇİ (BAĞLI)", fg=self.GREEN_ONLINE, bg="#0F2D1F")
                else:
                    self.status_badge.config(text="● EŞLEŞME BEKLİYOR", fg=self.AMBER_WAITING, bg="#2D270F")
            else:
                self.status_badge.config(text="● BAĞLANTI KESİLDİ", fg=self.RED_OFFLINE, bg="#2D0F0F")
        self.root.after(0, _set)

    def _process_log_queue(self):
        """Log kuyruğunu kontrol eder ve terminale basar."""
        lines = []
        while not self.log_queue.empty():
            try:
                lines.append(self.log_queue.get_nowait())
            except queue.Empty:
                break

        if lines:
            self.terminal_text.config(state=tk.NORMAL)
            for line in lines:
                tag = "info"
                if "[ERROR]" in line or "[-] " in line or "hatası" in line:
                    tag = "red"
                elif "[WARNING]" in line or "bekleniyor" in line:
                    tag = "yellow"
                elif "[✓]" in line or "tamamlandı" in line or "başarıyla" in line:
                    tag = "green"
                elif "[+]" in line or "komut" in line.lower():
                    tag = "cyan"

                self.terminal_text.insert(tk.END, line + "\n", tag)
            self.terminal_text.see(tk.END)
            self.terminal_text.config(state=tk.DISABLED)

        self.root.after(100, self._process_log_queue)

    def _clear_logs(self):
        self.terminal_text.config(state=tk.NORMAL)
        self.terminal_text.delete("1.0", tk.END)
        self.terminal_text.config(state=tk.DISABLED)

    def _simulate_test_command(self):
        """Kullanıcının sistemi denemesi için yerel bir test tetikler."""
        logger.info("[TEST] Masaüstü test tetiklendi: 'Masaüstündeki son indirilen belgeleri listele'")
        messagebox.showinfo(
            "Test Başlatıldı",
            "Test komutu günlüğe yazıldı. Supabase komut kuyruğu dinleniyor.\n\n"
            "Gerçek görevleri robot üzerinden sesle veya mobil uygulamadan gönderebilirsiniz."
        )

    def _setup_tray(self):
        """Windows Bildirim Alanı (System Tray) ikonu oluşturur."""
        try:
            # 64x64 boyutunda siber cyan renkli ikon
            img = Image.new("RGBA", (64, 64), color=(11, 15, 25, 255))
            from PIL import ImageDraw
            draw = ImageDraw.Draw(img)
            draw.rectangle([8, 8, 56, 56], fill=(0, 229, 255, 255))
            draw.rectangle([16, 16, 48, 48], fill=(19, 26, 38, 255))
            draw.ellipse([22, 22, 28, 28], fill=(0, 229, 255, 255))
            draw.ellipse([36, 22, 42, 28], fill=(0, 229, 255, 255))

            menu = pystray.Menu(
                pystray.MenuItem("KaironAgent Penceresini Aç", self.show_from_tray, default=True),
                pystray.MenuItem("Çıkış Yap", self.exit_app)
            )
            self.tray_icon = pystray.Icon("kaironagent", img, "KaironAgent (PC)", menu)
            threading.Thread(target=self.tray_icon.run, daemon=True).start()
        except Exception as e:
            logger.warning(f"Sistem tepsisi ikonu başlatılamadı: {e}")

    def hide_to_tray(self):
        self.root.withdraw()

    def show_from_tray(self, icon=None, item=None):
        self.root.after(0, self._restore_window)

    def _restore_window(self):
        self.root.deiconify()
        self.root.lift()
        self.root.focus_force()

    def on_window_close(self):
        res = messagebox.askyesnocancel(
            "KaironAgent",
            "KaironAgent'ı tamamen kapatmak mı istiyorsunuz?\n\n"
            "Evet: Ajan tamamen durdurulur.\n"
            "Hayır: Arka planda (Sistem Tepsisinde) çalışmaya devam eder."
        )
        if res is True:
            self.exit_app()
        elif res is False:
            self.hide_to_tray()

    def exit_app(self, icon=None, item=None):
        if self.tray_icon:
            try:
                self.tray_icon.stop()
            except Exception:
                pass
        if self.on_close_callback:
            self.on_close_callback()
        self.root.after(50, self.root.destroy)

    def run(self):
        self.root.mainloop()
