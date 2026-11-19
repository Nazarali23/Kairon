"""
KaironAgent Otonom Araclar (Tools) Modulu
- Guvenli dosya ve dizin yonetimi (Desktop, Downloads, Documents).
- Gercek dosya olusturma, listeleme, okuma, silme ve organize etme.
- Word (.docx) olusturma ve duzenleme (python-docx).
- Belge donusturme (PDF -> Word/Text, Text -> Word).
- Ekran goruntusu alma, Windows Media OCR ve durum analizi.
- Ucretsiz Telegram Bot entegrasyonu (fotograf/mesaj gonderimi).
- Groq / LLM Tool Calling semalari ve yurutucu fonksiyonlar.
"""

import os
import re
import io
import shutil
import tempfile
import subprocess
import webbrowser
from pathlib import Path
from typing import Dict, Any, List, Optional

import httpx
import pypdf
import docx
import winocr
from PIL import Image, ImageGrab

# Izinli Guvenli Kok Dizinler
SAFE_ROOTS = {
    "desktop": Path.home() / "Desktop",
    "downloads": Path.home() / "Downloads",
    "documents": Path.home() / "Documents",
}

# OneDrive Desktop Kontrolu
if not SAFE_ROOTS["desktop"].exists():
    od_desktop = Path.home() / "OneDrive" / "Desktop"
    if od_desktop.exists():
        SAFE_ROOTS["desktop"] = od_desktop


def resolve_folder(folder_key: str = "desktop") -> Path:
    """Gelen klasor adini temizler ve guvenli kok dizine esler."""
    if not folder_key:
        return SAFE_ROOTS["desktop"]

    # Gorunmez karakterleri (\u200b-\u200f, \ufeff) ve bosluklari temizle
    clean = re.sub(r'[\u200b-\u200f\ufeff\s]', '', str(folder_key)).lower()

    if any(w in clean for w in ["down", "indir", "yükle", "yukle"]):
        return SAFE_ROOTS["downloads"]
    elif any(w in clean for w in ["doc", "belge", "doküman", "dokuman"]):
        return SAFE_ROOTS["documents"]
    elif any(w in clean for w in ["desk", "masa", "masaüstü", "masaustu"]):
        return SAFE_ROOTS["desktop"]
    return SAFE_ROOTS["desktop"]


def resolve_safe_path(folder_key: str, filename: str) -> Path:
    folder = resolve_folder(folder_key)
    clean_name = os.path.basename(filename.strip())
    target = folder / clean_name
    # Guvenlik Kontrolu (Path Traversal Onleme)
    try:
        resolved = target.resolve()
        if not str(resolved).startswith(str(folder.resolve())):
            raise ValueError(f"Guvenlik engeli: Dizin disina cikilamaz: {filename}")
        return resolved
    except Exception:
        return target


# ==========================================
# ARAC UYGULAMALARI (Tool Implementations)
# ==========================================

def tool_list_files(folder: str = "desktop", extension: str = "*") -> Dict[str, Any]:
    """Masaustu veya klasordeki dosyalari listeler ve sayar."""
    target_dir = resolve_folder(folder)
    if not target_dir.exists():
        return {"status": "error", "message": f"Klasor bulunamadi: {target_dir}"}

    ext = (extension or "*").strip().lower()
    if ext.startswith("."):
        ext = ext[1:]

    files = []
    folders = []
    for item in target_dir.iterdir():
        if item.name.startswith("~$") or item.name.lower() in ("desktop.ini", "thumbs.db"):
            continue
        if item.is_dir():
            folders.append(item.name)
        elif item.is_file():
            if ext == "*" or ext == "all" or ext == "hepsi":
                files.append(item.name)
            else:
                if item.suffix.lower().lstrip(".") == ext:
                    files.append(item.name)

    files_sample = files[:35]
    return {
        "status": "ok",
        "folder": str(target_dir),
        "filter": extension,
        "total_count": len(files),
        "files_sample": files_sample,
        "note": f"Toplam {len(files)} dosya var. İlk {len(files_sample)} dosya listelendi." if len(files) > 35 else "Tüm dosyalar listelendi.",
        "subfolders_count": len(folders)
    }


def tool_create_file(filename: str, content: str = "", folder: str = "desktop") -> Dict[str, Any]:
    """Masaustunde veya izinli klasorde yeni bir metin dosyasi olusturur."""
    if not filename:
        return {"status": "error", "message": "Dosya adi belirtilmedi."}

    if "." not in filename:
        filename = f"{filename}.txt"

    target_path = resolve_safe_path(folder, filename)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        target_path.write_text(content, encoding="utf-8")
        size = target_path.stat().st_size
        return {
            "status": "ok",
            "message": f"'{target_path.name}' dosyasi basariyla olusturuldu.",
            "path": str(target_path),
            "size_bytes": size
        }
    except Exception as e:
        return {"status": "error", "message": f"Dosya olusturulurken hata: {e}"}


def tool_create_folder(folder_name: str, parent_folder: str = "desktop") -> Dict[str, Any]:
    """Yeni bir klasor olusturur."""
    if not folder_name:
        return {"status": "error", "message": "Klasor adi belirtilmedi."}

    target_dir = resolve_safe_path(parent_folder, folder_name)
    try:
        target_dir.mkdir(parents=True, exist_ok=True)
        return {
            "status": "ok",
            "message": f"'{target_dir.name}' klasoru basariyla olusturuldu.",
            "path": str(target_dir)
        }
    except Exception as e:
        return {"status": "error", "message": f"Klasor olusturulamadi: {e}"}


def tool_delete_file(filename: str, folder: str = "desktop") -> Dict[str, Any]:
    """Belirtilen dosyayi guvenli sekilde siler."""
    if not filename:
        return {"status": "error", "message": "Silinecek dosya adi belirtilmedi."}

    target_path = resolve_safe_path(folder, filename)
    if not target_path.exists():
        parent = target_path.parent
        match = None
        for f in parent.iterdir():
            if f.is_file() and f.name.lower() == target_path.name.lower():
                match = f
                break
        if match:
            target_path = match
        else:
            return {"status": "error", "message": f"'{filename}' dosyasi {folder} konumunda bulunamadi."}

    try:
        target_path.unlink()
        return {
            "status": "ok",
            "message": f"'{target_path.name}' dosyasi basariyla silindi.",
            "deleted_file": target_path.name
        }
    except Exception as e:
        return {"status": "error", "message": f"Dosya silinirken hata olustu: {e}"}


def tool_read_file(filename: str, folder: str = "desktop", max_chars: int = 3000) -> Dict[str, Any]:
    """Metin, Word (.docx) veya PDF belgesinin icerigini okur."""
    target_path = resolve_safe_path(folder, filename)
    if not target_path.exists():
        parent = target_path.parent
        for f in parent.iterdir():
            if f.is_file() and f.name.lower() == target_path.name.lower():
                target_path = f
                break

    if not target_path.exists():
        return {"status": "error", "message": f"'{filename}' bulunamadi."}

    ext = target_path.suffix.lower()
    try:
        if ext == ".pdf":
            reader = pypdf.PdfReader(str(target_path))
            text_parts = []
            for i, page in enumerate(reader.pages[:8]):
                t = page.extract_text()
                if t:
                    text_parts.append(f"--- Sayfa {i+1} ---\n{t.strip()}")
            full_text = "\n\n".join(text_parts)[:max_chars]
            return {
                "status": "ok",
                "filename": target_path.name,
                "type": "pdf",
                "pages_read": len(reader.pages),
                "content": full_text or "(PDF metin icermiyor veya taranmis resim)"
            }
        elif ext in (".docx", ".doc"):
            doc = docx.Document(str(target_path))
            text_lines = [p.text for p in doc.paragraphs if p.text.strip()]
            return {
                "status": "ok",
                "filename": target_path.name,
                "type": "docx",
                "paragraphs_count": len(text_lines),
                "content": "\n".join(text_lines)[:max_chars]
            }
        else:
            text = target_path.read_text(encoding="utf-8", errors="ignore")[:max_chars]
            return {
                "status": "ok",
                "filename": target_path.name,
                "type": "text",
                "content": text
            }
    except Exception as e:
        return {"status": "error", "message": f"Dosya okunamadi: {e}"}


def tool_create_or_edit_word(filename: str, title: str = "", content: str = "", folder: str = "desktop") -> Dict[str, Any]:
    """Word (.docx) belgesi olusturur veya mevcut belgeye yeni metin ekler."""
    if not filename.lower().endswith(".docx"):
        filename = f"{filename}.docx"

    target_path = resolve_safe_path(folder, filename)
    try:
        if target_path.exists():
            doc = docx.Document(str(target_path))
        else:
            doc = docx.Document()
            if title:
                doc.add_heading(title, level=0)

        if content:
            for p in content.split("\n"):
                clean_p = p.strip()
                if clean_p.startswith(("# ", "## ")):
                    doc.add_heading(clean_p.lstrip("# "), level=1)
                elif clean_p.startswith(("- ", "* ")):
                    doc.add_paragraph(clean_p.lstrip("-* "), style='List Bullet')
                elif clean_p:
                    doc.add_paragraph(clean_p)

        doc.save(str(target_path))
        return {
            "status": "ok",
            "message": f"'{target_path.name}' Word belgesi basariyla olusturuldu / guncellendi.",
            "path": str(target_path)
        }
    except Exception as e:
        return {"status": "error", "message": f"Word belgesi islenirken hata: {e}"}


def tool_convert_document(filename: str, target_format: str = "docx", folder: str = "desktop") -> Dict[str, Any]:
    """PDF, Word ve Metin belgeleri arasinda donusum yapar."""
    target_path = resolve_safe_path(folder, filename)
    if not target_path.exists():
        return {"status": "error", "message": f"Kaynak dosya bulunamadi: {filename}"}

    ext = target_path.suffix.lower()
    tgt = target_format.lower().lstrip(".")
    out_name = f"{target_path.stem}.{tgt}"
    out_path = target_path.parent / out_name

    try:
        if ext == ".pdf" and tgt in ("docx", "doc"):
            reader = pypdf.PdfReader(str(target_path))
            doc = docx.Document()
            doc.add_heading(f"{target_path.stem} (PDF Donusumu)", level=0)
            for i, page in enumerate(reader.pages):
                text = page.extract_text()
                if text:
                    doc.add_heading(f"Sayfa {i+1}", level=2)
                    doc.add_paragraph(text)
            doc.save(str(out_path))
            return {"status": "ok", "message": f"PDF basariyla Word belgesine donusturuldu: '{out_path.name}'", "path": str(out_path)}

        elif ext == ".pdf" and tgt == "txt":
            reader = pypdf.PdfReader(str(target_path))
            all_text = [p.extract_text() or "" for p in reader.pages]
            out_path.write_text("\n\n".join(all_text), encoding="utf-8")
            return {"status": "ok", "message": f"PDF metin dosyasina donusturuldu: '{out_path.name}'", "path": str(out_path)}

        elif ext in (".txt", ".md") and tgt in ("docx", "doc"):
            content = target_path.read_text(encoding="utf-8", errors="ignore")
            doc = docx.Document()
            doc.add_heading(target_path.stem, level=0)
            for line in content.split("\n"):
                if line.strip():
                    doc.add_paragraph(line)
            doc.save(str(out_path))
            return {"status": "ok", "message": f"Metin dosyasi Word belgesine donusturuldu: '{out_path.name}'", "path": str(out_path)}

        return {"status": "error", "message": f"{ext} formatindan {tgt} formatina donusum desteklenmiyor."}
    except Exception as e:
        return {"status": "error", "message": f"Donusum hatasi: {e}"}


def tool_capture_screen(save_filename: str = "Ekran_Goruntusu.png", folder: str = "desktop") -> Dict[str, Any]:
    """Masaustunun anlik ekran goruntusunu alir ve kaydeder."""
    target_path = resolve_safe_path(folder, save_filename)
    try:
        img = None
        try:
            img = ImageGrab.grab(all_screens=True)
        except Exception:
            pass

        if img is None:
            # PowerShell .NET yedek ekran yakalama
            ps_code = f"""
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save('{str(target_path)}', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
"""
            subprocess.run(["powershell", "-NoProfile", "-Command", ps_code], capture_output=True, timeout=10)

        if img is not None:
            img.save(str(target_path))

        if target_path.exists() and target_path.stat().st_size > 0:
            return {
                "status": "ok",
                "message": f"Ekran goruntusu basariyla alindi: '{target_path.name}'",
                "path": str(target_path),
                "size_bytes": target_path.stat().st_size
            }
        else:
            return {"status": "error", "message": "Ekran yakalanamadi (Goruntu servisi yanit vermedi)."}
    except Exception as e:
        return {"status": "error", "message": f"Ekran goruntusu alma hatasi: {e}"}


async def tool_analyze_screen(custom_question: str = "", send_telegram: bool = False, bot_token: str = "", chat_id: str = "", proxy: str = "") -> Dict[str, Any]:
    """
    Ekran goruntusu alir, Windows Media OCR ile tum metinleri tarar ve yapay zeka ile durumu ozetler.
    Ornek: 'AI IDE'de komut bitti mi?', 'Derleme tamamlandi mi?'
    """
    temp_img_path = resolve_folder("desktop") / "kairon_screen_temp.png"
    cap_res = tool_capture_screen(save_filename=temp_img_path.name, folder="desktop")
    if not temp_img_path.exists():
        temp_img_path = Path(tempfile.gettempdir()) / "kairon_screen_temp.png"
        tool_capture_screen(save_filename=temp_img_path.name, folder="desktop")

    ocr_text = ""
    if temp_img_path.exists():
        try:
            img = Image.open(str(temp_img_path))
            ocr_res = await winocr.recognize_pil(img)
            ocr_text = ocr_res.text.strip()
        except Exception as e:
            ocr_text = f"(OCR calistirilamadi: {e})"

    # Telegram gonderimi istendiyse
    telegram_status = ""
    if send_telegram:
        tg_res = await tool_send_telegram(
            photo_path=str(temp_img_path),
            message=f"Kairon Ekran Goruntusu\nDurum: {custom_question or 'Anlik Ekran'}",
            bot_token=bot_token,
            chat_id=chat_id,
            proxy=proxy
        )
        telegram_status = tg_res.get("message", "")

    return {
        "status": "ok",
        "question": custom_question,
        "ocr_text_length": len(ocr_text),
        "ocr_text": ocr_text[:3500],
        "image_path": str(temp_img_path),
        "telegram_status": telegram_status
    }


async def tool_send_telegram(
    file_path: Optional[str] = None,
    photo_path: Optional[str] = None, 
    message: str = "", 
    bot_token: str = "", 
    chat_id: str = "",
    proxy: str = ""
) -> Dict[str, Any]:
    """Telegram uzerinden kullaniciya anlik ucretsiz mesaj, dosya (PDF, Word, TXT vb.) veya fotograf gonderir."""
    token = bot_token.strip()
    chat = chat_id.strip()

    if not token or not chat:
        return {
            "status": "info",
            "message": "Telegram Bot Token veya Chat ID tanimli degil. (config.toml altinda [telegram] bolumune ekleyebilirsiniz)."
        }

    # Hedef dosya tespiti (file_path veya photo_path)
    target_path = None
    candidate = file_path or photo_path
    if candidate:
        p = Path(candidate)
        if p.exists() and p.is_file():
            target_path = p
        else:
            c_name = p.name.lower()
            for r in SAFE_ROOTS.values():
                if not r.exists():
                    continue
                for f in r.iterdir():
                    if f.is_file() and f.name.lower() == c_name:
                        target_path = f
                        break
                if target_path:
                    break

    client_kwargs: Dict[str, Any] = {
        "timeout": 30.0,
        "headers": {"User-Agent": "Mozilla/5.0"}
    }
    if proxy and proxy.strip():
        client_kwargs["proxy"] = proxy.strip()

    try:
        async with httpx.AsyncClient(**client_kwargs) as client:
            if target_path and target_path.exists():
                ext = target_path.suffix.lower()
                caption_text = (message or f"{target_path.name}")[:1024]

                if ext in [".png", ".jpg", ".jpeg"] and (photo_path or "foto" in (message or "").lower()):
                    url = f"https://api.telegram.org/bot{token}/sendPhoto"
                    with open(target_path, "rb") as f:
                        files = {"photo": (target_path.name, f)}
                        data = {"chat_id": chat, "caption": caption_text}
                        resp = await client.post(url, data=data, files=files)
                else:
                    # PDF, Word (.docx), TXT, vb. belgeleri dosya (sendDocument) olarak gonder
                    url = f"https://api.telegram.org/bot{token}/sendDocument"
                    with open(target_path, "rb") as f:
                        files = {"document": (target_path.name, f)}
                        data = {"chat_id": chat, "caption": caption_text}
                        resp = await client.post(url, data=data, files=files)

                if resp.status_code == 200:
                    return {"status": "ok", "message": f"'{target_path.name}' dosyası Telegram üzerinden başarıyla gönderildi."}
            else:
                url = f"https://api.telegram.org/bot{token}/sendMessage"
                resp = await client.post(url, json={"chat_id": chat, "text": message or "Kairon Bildirimi"})

            if resp.status_code == 200:
                return {"status": "ok", "message": "Telegram bildirimi basariyla gonderildi."}
            elif resp.status_code == 502:
                return {
                    "status": "error",
                    "message": "Telegram sunucusu gecici olarak 502 Bad Gateway dondurdu. Telegram DC senkronizasyonu bekleniyor veya gecici bir Telegram sorunu var."
                }
            elif resp.status_code == 403:
                return {
                    "status": "error",
                    "message": "Telegram 403: Bot kullanici tarafindan baslatilmamis. Lutfen Telegram uygulamasindan botunuza gidip 'BASLAT' (/start) butonuna basin."
                }
            else:
                return {"status": "error", "message": f"Telegram API hatasi ({resp.status_code}): {resp.text}"}
    except httpx.TimeoutException:
        return {
            "status": "error",
            "message": "Telegram baglanti zaman asimi: Telegram API sunucusu zamaninda yanit vermedi."
        }
    except Exception as e:
        err_msg = str(e).strip() or type(e).__name__
        return {"status": "error", "message": f"Telegram iletisim hatasi: {err_msg}"}


def tool_organize_files(pattern: str = "pdf", target_folder: str = "PDF_Belgeleri", folder: str = "desktop") -> Dict[str, Any]:
    """Dosyalari kategorilerine veya belirtilen klasore tasir."""
    root = resolve_folder(folder)
    pat = (pattern or "").lower()

    if pat in ("all", "organize_all", "hepsi", "duzenle", "düzenle", "toparla"):
        categories = {
            "PDF_Belgeleri": [".pdf"],
            "Gorseller": [".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"],
            "Dokumanlar": [".docx", ".doc", ".txt", ".xlsx", ".xls", ".pptx", ".ppt"],
            "Arsivler": [".zip", ".rar", ".7z", ".tar", ".gz"]
        }
        all_files = [f for f in root.iterdir() if f.is_file() and not f.name.startswith((".", "~$")) and f.name.lower() != "desktop.ini"]
        moved = []
        for f in all_files:
            dest_cat = None
            for cat_name, exts in categories.items():
                if f.suffix.lower() in exts:
                    dest_cat = cat_name
                    break
            if dest_cat:
                cat_dir = root / dest_cat
                cat_dir.mkdir(exist_ok=True)
                dest = cat_dir / f.name
                c = 2
                while dest.exists():
                    dest = cat_dir / f"{f.stem} ({c}){f.suffix}"
                    c += 1
                try:
                    shutil.move(str(f), str(dest))
                    moved.append(f"{f.name} -> {dest_cat}")
                except Exception:
                    pass

        return {
            "status": "ok",
            "message": f"Toplam {len(moved)} adet dosya kategorilerine ayrilarak duzenlendi.",
            "moved_count": len(moved),
            "details": moved
        }
    else:
        target_dir = root / target_folder
        target_dir.mkdir(exist_ok=True)
        ext = pat.lstrip(".")
        files_to_move = [f for f in root.iterdir() if f.is_file() and f.suffix.lower().lstrip(".") == ext]
        moved = []
        for f in files_to_move:
            dest = target_dir / f.name
            c = 2
            while dest.exists():
                dest = target_dir / f"{f.stem} ({c}){f.suffix}"
                c += 1
            try:
                shutil.move(str(f), str(dest))
                moved.append(f.name)
            except Exception:
                pass

        return {
            "status": "ok",
            "message": f"{len(moved)} adet dosya '{target_folder}' klasorune tasindi.",
            "moved_count": len(moved),
            "details": moved
        }


def tool_open_app(app_name: str) -> Dict[str, Any]:
    """Sistem uygulamalarini acar."""
    a = (app_name or "").lower().strip()
    try:
        if any(x in a for x in ["not defter", "notepad"]):
            subprocess.Popen(["notepad.exe"])
            return {"status": "ok", "message": "Not Defteri baslatildi."}
        elif any(x in a for x in ["hesap", "calc"]):
            subprocess.Popen(["calc.exe"])
            return {"status": "ok", "message": "Hesap Makinesi baslatildi."}
        elif any(x in a for x in ["tarayici", "tarayıcı", "chrome", "google", "browser"]):
            webbrowser.open("https://google.com")
            return {"status": "ok", "message": "Web tarayicisi baslatildi."}
        elif any(x in a for x in ["explorer", "klasor", "dosya gezgini"]):
            subprocess.Popen(["explorer.exe", str(SAFE_ROOTS["desktop"])])
            return {"status": "ok", "message": "Dosya Gezgini masaustunde acildi."}
        else:
            return {"status": "error", "message": f"'{app_name}' uygulamasi icin guvenli baslatici bulunamadi."}
    except Exception as e:
        return {"status": "error", "message": f"Uygulama baslatilamadi: {e}"}


# ==========================================
# GROQ TOOL CALLING SEMALARI (JSON Schemas)
# ==========================================

AGENT_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "Masaustu, Indirilenler veya Belgeler klasorundeki dosyalari listeler, sayar veya filtreler (orn: kac tane pdf dosyasi var).",
            "parameters": {
                "type": "object",
                "properties": {
                    "folder": {
                        "type": "string",
                        "description": "Taranacak klasor konumu: 'downloads' (indirilenler), 'desktop' (masaüstü) veya 'documents' (belgeler)"
                    },
                    "extension": {
                        "type": "string",
                        "description": "Dosya uzantisi filtresi (orn: .pdf, .txt, .docx veya hepsi icin *)"
                    }
                },
                "required": ["folder"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_file",
            "description": "Masaustunde veya izinli klasorde yeni bir metin/kod dosyasi olusturur ve icine icerik yazar.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Olusturulacak dosya adi (orn: Kairon-text.txt, notlar.txt)"
                    },
                    "content": {
                        "type": "string",
                        "description": "Dosyanin icine yazilacak metin veya icerik"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Hedef klasor (varsayilan: desktop, downloads, documents)"
                    }
                },
                "required": ["filename"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_or_edit_word",
            "description": "Microsoft Word (.docx) belgesi olusturur veya mevcut Word belgesine icerik/baslik ekler.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Word dosya adi (orn: Rapor.docx)"
                    },
                    "title": {
                        "type": "string",
                        "description": "Belge basligi"
                    },
                    "content": {
                        "type": "string",
                        "description": "Belge icerik paragraflari veya maddeleri"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Hedef klasor (desktop, downloads, documents)"
                    }
                },
                "required": ["filename"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "convert_document",
            "description": "PDF, Word ve Metin belgeleri arasinda donusum yapar (orn: PDF'i Word'e veya Metne cevirir, Metni Word yapar).",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Donusturulecek kaynak dosya adi (orn: tez.pdf)"
                    },
                    "target_format": {
                        "type": "string",
                        "description": "Hedef format ('docx', 'txt')"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Dosyanin bulundugu klasor"
                    }
                },
                "required": ["filename", "target_format"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "capture_screen",
            "description": "Bilgisayar ekraninin anlik ekran goruntusunu alir ve kaydeder.",
            "parameters": {
                "type": "object",
                "properties": {
                    "save_filename": {
                        "type": "string",
                        "description": "Kaydedilecek resim adi (varsayilan: Ekran_Goruntusu.png)"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Kayit klasoru (desktop, downloads, documents)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "analyze_screen",
            "description": "Ekrani yakalayip OCR ile metinleri okur ve kullanicinin sorusuna gore IDE, kod veya acik uygulamalarin durumunu analiz eder.",
            "parameters": {
                "type": "object",
                "properties": {
                    "custom_question": {
                        "type": "string",
                        "description": "Kullanicinin analiz istegi (orn: 'IDE'deki derleme bitti mi?', 'Ekrandaki hata nedir?')"
                    },
                    "send_telegram": {
                        "type": "boolean",
                        "description": "Goruntunun Telegram uzerinden kullaniciya gonderilip gonderilmeyecegi"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "send_telegram",
            "description": "Kullaniciya Telegram uzerinden anlik bildirim, dosya (PDF, Word, TXT vb.) veya fotograf gonderir.",
            "parameters": {
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "Gonderilecek mesaj metni veya dosya aciklamasi (caption)"
                    },
                    "file_path": {
                        "type": "string",
                        "description": "Telegram ile kullaniciya gonderilecek dosyanin tam yolu veya adi (orn: rapor.pdf, tez.docx, ekran.png)"
                    }
                },
                "required": ["message"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_folder",
            "description": "Masaustunde veya izinli klasorde yeni bir dizin/klasor olusturur.",
            "parameters": {
                "type": "object",
                "properties": {
                    "folder_name": {
                        "type": "string",
                        "description": "Olusturulacak klasorun adi (orn: Kairon-Projeleri, Belgelerim)"
                    },
                    "parent_folder": {
                        "type": "string",
                        "description": "Ust klasor (varsayilan: desktop)"
                    }
                },
                "required": ["folder_name"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "delete_file",
            "description": "Masaustu veya klasorden belirtilen dosyayi guvenli sekilde siler.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Silinecek dosya adi (orn: 1.pdf, gecici.txt)"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Dosyanin bulundugu klasor (varsayilan: desktop)"
                    }
                },
                "required": ["filename"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Belirtilen metin (.txt, .md, .py), Word (.docx) veya PDF belgesinin icerigini okur.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Okunacak dosya adi (orn: rapor.pdf, not.txt, tez.docx)"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Klasor (varsayilan: desktop)"
                    }
                },
                "required": ["filename"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "organize_files",
            "description": "Masaustundeki dosyalari kategorilerine (PDF, Gorseller vb.) ayirir ya da belirli turdeki dosyalari bir klasore tasir.",
            "parameters": {
                "type": "object",
                "properties": {
                    "pattern": {
                        "type": "string",
                        "description": "Tasinacak dosya turu (orn: 'pdf' ya da tum masaustunu toplamak icin 'all')"
                    },
                    "target_folder": {
                        "type": "string",
                        "description": "Hedef klasor adi (varsayilan: PDF_Belgeleri)"
                    },
                    "folder": {
                        "type": "string",
                        "description": "Klasor konumu"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "open_application",
            "description": "Not Defteri, Hesap Makinesi, Tarayici gibi sistem uygulamalarini acar.",
            "parameters": {
                "type": "object",
                "properties": {
                    "app_name": {
                        "type": "string",
                        "description": "Uygulama adi (notepad, calc, browser, explorer)"
                    }
                },
                "required": ["app_name"]
            }
        }
    }
]


async def dispatch_tool(name: str, arguments: Dict[str, Any], config: Any = None) -> Dict[str, Any]:
    """Gelen fonksiyon cagrisini ilgili araca yonlendirir ve asenkron olarak calistirir."""
    tg_token = getattr(config.telegram, "bot_token", "") if config and hasattr(config, "telegram") else ""
    tg_chat = getattr(config.telegram, "chat_id", "") if config and hasattr(config, "telegram") else ""
    tg_proxy = getattr(config.telegram, "proxy", "") if config and hasattr(config, "telegram") else ""

    if name == "list_files":
        return tool_list_files(
            folder=arguments.get("folder", "desktop"),
            extension=arguments.get("extension", "*")
        )
    elif name == "create_file":
        return tool_create_file(
            filename=arguments.get("filename", ""),
            content=arguments.get("content", ""),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "create_or_edit_word":
        return tool_create_or_edit_word(
            filename=arguments.get("filename", ""),
            title=arguments.get("title", ""),
            content=arguments.get("content", ""),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "convert_document":
        return tool_convert_document(
            filename=arguments.get("filename", ""),
            target_format=arguments.get("target_format", "docx"),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "capture_screen":
        return tool_capture_screen(
            save_filename=arguments.get("save_filename", "Ekran_Goruntusu.png"),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "analyze_screen":
        return await tool_analyze_screen(
            custom_question=arguments.get("custom_question", ""),
            send_telegram=bool(arguments.get("send_telegram", False)),
            bot_token=tg_token,
            chat_id=tg_chat,
            proxy=tg_proxy
        )
    elif name == "send_telegram":
        return await tool_send_telegram(
            message=arguments.get("message", ""),
            file_path=arguments.get("file_path") or arguments.get("photo_path") or arguments.get("document_path"),
            photo_path=arguments.get("photo_path"),
            bot_token=tg_token,
            chat_id=tg_chat,
            proxy=tg_proxy
        )
    elif name == "create_folder":
        return tool_create_folder(
            folder_name=arguments.get("folder_name", ""),
            parent_folder=arguments.get("parent_folder", "desktop")
        )
    elif name == "delete_file":
        return tool_delete_file(
            filename=arguments.get("filename", ""),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "read_file":
        return tool_read_file(
            filename=arguments.get("filename", ""),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "organize_files":
        return tool_organize_files(
            pattern=arguments.get("pattern", "pdf"),
            target_folder=arguments.get("target_folder", "PDF_Belgeleri"),
            folder=arguments.get("folder", "desktop")
        )
    elif name == "open_application":
        return tool_open_app(
            app_name=arguments.get("app_name", "")
        )
    return {"status": "error", "message": f"Bilinmeyen arac: {name}"}
