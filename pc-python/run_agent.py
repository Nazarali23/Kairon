"""
KaironAgent PC Başlatıcı
Masaüstü görsel arayüzünü (GUI) başlatır.
"""
import sys
import os

# src klasörünü sys.path'e ekle
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))

from kaironagent.app import main

if __name__ == "__main__":
    main()
