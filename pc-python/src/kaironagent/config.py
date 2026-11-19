"""
KaironAgent Yapılandırma ve Sistem Bilgisi Modülü
- TOML yapılandırma dosyasını okur.
- Windows DPI ekran ölçeğini dinamik olarak algılar.
- Hassas anahtarları (HMAC, Supabase service_role, Groq) Windows Keyring'den çeker.
"""

import os
import sys
import re
import tomllib
import ctypes
from pathlib import Path
from dataclasses import dataclass, field

# DPI Farkındalığını Windows üzerinde etkinleştir ve ölçeği hesapla
def detect_screen_scale() -> float:
    """Windows ana ekran DPI ölçeğini (1.0 = %100, 1.25 = %125, 1.5 = %150) döndürür."""
    if sys.platform != "win32":
        return 1.0

    try:
        # Per-Monitor V2 DPI awareness (Windows 10 1703+)
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass

    try:
        hdc = ctypes.windll.user32.GetDC(0)
        # LOGPIXELSX = 88
        dpi_x = ctypes.windll.gdi32.GetDeviceCaps(hdc, 88)
        ctypes.windll.user32.ReleaseDC(0, hdc)
        scale = round(dpi_x / 96.0, 2)
        return scale
    except Exception:
        return 1.25  # Yedek varsayılan

def extract_c_define_string(content: str, macro_name: str) -> str:
    """C/C++ başlık dosyalarındaki tek veya çok satırlı (#define X \\ "...") makrolarını ayıklar."""
    pattern = rf'#define\s+{macro_name}\b(.*?)(?=\n\s*#define|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return ""
    block = match.group(1)
    parts = re.findall(r'"([^"]*)"', block)
    return "".join(parts).strip()

def get_secret(name: str, default: str = "") -> str:
    """Önce ortam değişkenine (ENV), yoksa Windows Keyring'e bakar."""
    env_val = os.environ.get(name.upper())
    if env_val:
        return env_val

    try:
        import keyring
        val = keyring.get_password("KaironAgent", name)
        if val:
            return val
    except Exception:
        pass

    return default

@dataclass
class CloudConfig:
    supabase_url: str = "https://your-project.supabase.co"
    poll_active_s: float = 3.0
    poll_idle_s: float = 10.0
    heartbeat_s: float = 25.0

@dataclass
class SecurityConfig:
    roots: list[str] = field(default_factory=lambda: ["desktop", "downloads", "documents"])
    max_files_per_command: int = 200
    timestamp_window_s: int = 90
    auto_confirm_max_files: int = 5  # Kullanıcı isteği: <= 5 otomatik, fazlası onaylı
    allow_delete: bool = False
    rate_limit_per_min: int = 3

@dataclass
class PlannerConfig:
    provider: str = "groq"
    model: str = "qwen/qwen3.8-27b"  # Robot firmware ile aynı çalışan Groq modeli
    temperature: float = 0.0
    send_pdf_text_to_llm: bool = false if False else False

@dataclass
class CursorConfig:
    enabled: bool = False
    max_icons_to_visit: int = 6
    abort_on_user_mouse: bool = True
    hotkey_pause: str = "ctrl+alt+esc"
    screen_scale: float = field(default_factory=detect_screen_scale)

@dataclass
class RobotConfig:
    say_max_chars: int = 250

@dataclass
class AppConfig:
    cloud: CloudConfig = field(default_factory=CloudConfig)
    security: SecurityConfig = field(default_factory=SecurityConfig)
    planner: PlannerConfig = field(default_factory=PlannerConfig)
    cursor: CursorConfig = field(default_factory=CursorConfig)
    robot: RobotConfig = field(default_factory=RobotConfig)

    # Keyring sırları
    hmac_secret: str = ""
    service_role_key: str = ""
    groq_api_key: str = ""

def load_config() -> AppConfig:
    """Konfigürasyonu yerel config.toml veya varsayılanlardan yükler."""
    cfg = AppConfig()

    paths_to_check = [
        Path.cwd() / "config.toml",
        Path.cwd() / "pc-python" / "config.toml",
        Path.home() / "AppData" / "Roaming" / "KaironAgent" / "config.toml"
    ]

    for p in paths_to_check:
        if p.exists():
            try:
                with open(p, "rb") as f:
                    data = tomllib.load(f)

                if "cloud" in data:
                    c = data["cloud"]
                    cfg.cloud.supabase_url = c.get("supabase_url", cfg.cloud.supabase_url)
                    cfg.cloud.poll_active_s = float(c.get("poll_active_s", cfg.cloud.poll_active_s))
                    cfg.cloud.poll_idle_s = float(c.get("poll_idle_s", cfg.cloud.poll_idle_s))
                    cfg.cloud.heartbeat_s = float(c.get("heartbeat_s", cfg.cloud.heartbeat_s))

                if "security" in data:
                    s = data["security"]
                    cfg.security.roots = s.get("roots", cfg.security.roots)
                    cfg.security.max_files_per_command = int(s.get("max_files_per_command", cfg.security.max_files_per_command))
                    cfg.security.timestamp_window_s = int(s.get("timestamp_window_s", cfg.security.timestamp_window_s))
                    cfg.security.auto_confirm_max_files = int(s.get("auto_confirm_max_files", cfg.security.auto_confirm_max_files))
                    cfg.security.allow_delete = bool(s.get("allow_delete", cfg.security.allow_delete))
                    cfg.security.rate_limit_per_min = int(s.get("rate_limit_per_min", cfg.security.rate_limit_per_min))

                if "planner" in data:
                    pl = data["planner"]
                    cfg.planner.provider = pl.get("provider", cfg.planner.provider)
                    cfg.planner.model = pl.get("model", cfg.planner.model)
                    cfg.planner.temperature = float(pl.get("temperature", cfg.planner.temperature))
                    cfg.planner.send_pdf_text_to_llm = bool(pl.get("send_pdf_text_to_llm", cfg.planner.send_pdf_text_to_llm))

                if "cursor" in data:
                    cu = data["cursor"]
                    cfg.cursor.enabled = bool(cu.get("enabled", cfg.cursor.enabled))
                    cfg.cursor.max_icons_to_visit = int(cu.get("max_icons_to_visit", cfg.cursor.max_icons_to_visit))
                    cfg.cursor.abort_on_user_mouse = bool(cu.get("abort_on_user_mouse", cfg.cursor.abort_on_user_mouse))
                    cfg.cursor.hotkey_pause = cu.get("hotkey_pause", cfg.cursor.hotkey_pause)

                if "robot" in data:
                    ro = data["robot"]
                    cfg.robot.say_max_chars = int(ro.get("say_max_chars", cfg.robot.say_max_chars))

                break
            except Exception as e:
                print(f"[!] Yapılandırma dosyası okuma hatası ({p}): {e}")

    # Sırları yükle (Keyring / ENV)
    cfg.hmac_secret = get_secret("hmac_secret")
    cfg.service_role_key = get_secret("service_role_key") or get_secret("supabase_key") or get_secret("supabase_secret")
    cfg.groq_api_key = get_secret("groq_api_key")

    # Supabase URL kontrolü (Keyring / ENV)
    keyring_url = get_secret("supabase_url")
    if keyring_url:
        cfg.cloud.supabase_url = keyring_url

    # sketch_oct30a/secrets.h içinden eksik olanları otomatik tamamla
    for sp in [Path.cwd() / "sketch_oct30a" / "secrets.h", Path.cwd().parent / "sketch_oct30a" / "secrets.h"]:
        if sp.exists():
            try:
                content = sp.read_text(encoding="utf-8")
                if cfg.cloud.supabase_url == "https://your-project.supabase.co":
                    url = extract_c_define_string(content, "SUPABASE_URL")
                    if url:
                        cfg.cloud.supabase_url = url

                if not cfg.service_role_key:
                    # RLS kapalı olduğu için secrets.h içindeki SUPABASE_KEY otomatik kullanılır
                    supa_k = extract_c_define_string(content, "SUPABASE_KEY")
                    if supa_k:
                        cfg.service_role_key = supa_k

                if not cfg.groq_api_key:
                    groq_k = extract_c_define_string(content, "GROQ_KEY")
                    if groq_k:
                        cfg.groq_api_key = groq_k

                if not cfg.hmac_secret:
                    hmac_k = extract_c_define_string(content, "PC_HMAC_KEY")
                    if hmac_k:
                        cfg.hmac_secret = hmac_k
                break
            except Exception:
                pass

    return cfg
