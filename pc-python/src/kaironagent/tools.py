"""
KaironAgent Otonom Araclar (Tools) Modulu
- Guvenli dosya ve dizin yonetimi (Desktop, Downloads, Documents).
- Gercek dosya olusturma, listeleme, okuma, silme ve organize etme.
- Groq / LLM Tool Calling semalari ve yurutucu fonksiyonlar.
"""

import os
import re
import shutil
import subprocess
import webbrowser
from pathlib import Path
from typing import Dict, Any, List, Optional

import pypdf

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
    k = (folder_key or "desktop").strip().lower()
    if k in ("desktop", "masaüstü", "masaustu"):
        return SAFE_ROOTS["desktop"]
    elif k in ("downloads", "indirilenler", "indirilen"):
        return SAFE_ROOTS["downloads"]
    elif k in ("documents", "belgeler", "belgelerim"):
        return SAFE_ROOTS["documents"]
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

    return {
        "status": "ok",
        "folder": str(target_dir),
        "filter": extension,
        "total_count": len(files),
        "files": files,
        "subfolders_count": len(folders)
    }


def tool_create_file(filename: str, content: str = "", folder: str = "desktop") -> Dict[str, Any]:
    """Masaustunde veya izinli klasorde yeni bir metin dosyasi olusturur."""
    if not filename:
        return {"status": "error", "message": "Dosya adi belirtilmedi."}

    # Uzanti yoksa varsayilan .txt ekle
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
        # Buyuk/kucuk harf duyarsiz arama yap
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


def tool_read_file(filename: str, folder: str = "desktop", max_chars: int = 2500) -> Dict[str, Any]:
    """Metin veya PDF dosyasinin icerigini okur."""
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
            for i, page in enumerate(reader.pages[:5]):
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
        # Belirli bir uzanti tasima (orn: pdf)
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
            "description": "Masaustu veya belirtilen klasordeki dosyalari listeler, sayar veya filtreler (orn: kac tane pdf dosyasi var).",
            "parameters": {
                "type": "object",
                "properties": {
                    "folder": {
                        "type": "string",
                        "enum": ["desktop", "downloads", "documents"],
                        "description": "Taranacak klasor (varsayilan: desktop)"
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
                        "enum": ["desktop", "downloads", "documents"],
                        "description": "Hedef klasor (varsayilan: desktop)"
                    }
                },
                "required": ["filename"]
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
                        "enum": ["desktop", "downloads", "documents"],
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
                        "enum": ["desktop", "downloads", "documents"],
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
            "description": "Belirtilen metin (.txt, .md, .py) veya PDF belgesinin icerigini okur.",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {
                        "type": "string",
                        "description": "Okunacak dosya adi (orn: rapor.pdf, not.txt)"
                    },
                    "folder": {
                        "type": "string",
                        "enum": ["desktop", "downloads", "documents"],
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
                        "description": "Tasınacak dosya turu (orn: 'pdf' ya da tum masaustunu toplamak icin 'all')"
                    },
                    "target_folder": {
                        "type": "string",
                        "description": "Hedef klasor adi (varsayilan: PDF_Belgeleri)"
                    },
                    "folder": {
                        "type": "string",
                        "enum": ["desktop", "downloads", "documents"],
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


def dispatch_tool(name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    """Gelen fonksiyon cagrisini ilgili araca yonlendirir ve calistirir."""
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
