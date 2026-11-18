"""
KaironAgent Hassas Anahtar Kurulum Aracı (Windows Keyring)
Bu betik ile Supabase URL ve gizli anahtarları güvenli şekilde Windows Kimlik Bilgisi Yöneticisine kaydedebilirsiniz.
"""

import getpass
import keyring

def set_key(name: str, prompt_text: str, is_secret: bool = True):
    print(f"\n{prompt_text}")
    existing = keyring.get_password("KaironAgent", name)
    if existing:
        mask = existing[:6] + "..." + existing[-4:] if len(existing) > 10 else "***"
        print(f"(Mevcut değer: {mask} - Değiştirmemek için Enter'a basın)")

    if is_secret:
        val = getpass.getpass("Değer: ").strip()
    else:
        val = input("Değer: ").strip()

    if val:
        keyring.set_password("KaironAgent", name, val)
        print(f"[✓] '{name}' başarıyla kaydedildi.")
    else:
        if existing:
            print(f"[-] Mevcut '{name}' korundu.")
        else:
            print(f"[!] '{name}' boş bırakıldı.")

def main():
    print("=" * 60)
    print("  KAIRON AGENT - ANAHTAR VE GİZLİLİK KURULUMU")
    print("=" * 60)

    set_key("supabase_url", "1. Supabase Project URL (https://<id>.supabase.co):", is_secret=False)
    set_key("service_role_key", "2. Supabase Service Role Key (service_role secret - RLS aşmak için):", is_secret=True)
    set_key("hmac_secret", "3. Robot ve PC Arasındaki HMAC Secret (64 karakter hex):", is_secret=True)
    set_key("groq_api_key", "4. Groq API Key (gsk_...):", is_secret=True)

    print("\n[✓] Tüm anahtar kurulumları tamamlandı.")
    print("Artık 'python -m kaironagent' ile ajanı güvenle başlatabilirsiniz.")
    print("=" * 60)

if __name__ == "__main__":
    main()
