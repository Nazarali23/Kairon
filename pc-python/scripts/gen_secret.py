"""
KaironAgent HMAC Gizli Anahtarı Üretici ve Keyring Kaydedici
Robot (ESP32) ile PC Ajanı arasındaki güvenli iletişim için 32 baytlık (64 karakter hex)
kriptografik gizli anahtar üretir.
"""

import secrets
import sys

def main():
    print("=" * 65)
    print("  KAIRON AGENT - GÜVENLİK ANAHTARI ÜRETİCİ (HMAC-SHA256)")
    print("=" * 65)

    # 32 bayt (64 hex karakter) rastgele anahtar
    secret = secrets.token_hex(32)

    print("\n[+] Yeni HMAC Anahtarı Başarıyla Üretildi:")
    print(f"\n    {secret}\n")

    print("-" * 65)
    print("1. ROBOT TARAFI (ESP32):")
    print("   secrets.h dosyanıza şu satırı ekleyin:")
    print(f'   #define PC_HMAC_KEY "{secret}"')
    print("-" * 65)

    # Keyring kontrolü ve kaydetme
    try:
        import keyring
        keyring.set_password("KaironAgent", "hmac_secret", secret)
        print("2. PC TARAFI (Windows Kimlik Bilgisi Yöneticisi):")
        print("   [BAŞARILI] HMAC anahtarı Windows Keyring'e güvenle kaydedildi.")
        print("              (Servis: KaironAgent, Kullanıcı: hmac_secret)")
    except ImportError:
        print("2. PC TARAFI:")
        print("   [BİLGİ] 'keyring' kütüphanesi henüz yüklü değil.")
        print(f"   pip install keyring sonrası şunu çalıştırabilirsiniz:")
        print(f"   python -c \"import keyring; keyring.set_password('KaironAgent', 'hmac_secret', '{secret}')\"")

    print("=" * 65)

if __name__ == "__main__":
    main()
