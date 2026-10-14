#!/usr/bin/env python3
"""Menambahkan izin dan konfigurasi platform setelah `flutter create .`.

Pemakaian (dari folder proyek):
    flutter create --platforms=android,ios --org com.kelompok --project-name warga_siaga .
    python3 tool/setup_platform.py

Aman dijalankan berulang kali (idempoten). Skrip ini hanya mengubah
android/app/src/main/AndroidManifest.xml dan ios/Runner/Info.plist.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
PLIST = ROOT / "ios/Runner/Info.plist"

ANDROID_PERMS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.CAMERA",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.VIBRATE",
]

QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="tel"/>
        </intent>
    </queries>
"""

PLIST_KEYS = {
    "NSLocationWhenInUseUsageDescription":
        "Lokasi dipakai untuk melampirkan koordinat laporan, mengirim SOS, dan menampilkan posko terdekat.",
    "NSCameraUsageDescription":
        "Kamera dipakai untuk memotret kejadian yang dilaporkan.",
}
PLIST_QUERY = ("LSApplicationQueriesSchemes", ["tel"])


def patch_manifest() -> bool:
    if not MANIFEST.exists():
        print(f"! {MANIFEST} tidak ada. Jalankan `flutter create` dulu.")
        return False
    text = MANIFEST.read_text(encoding="utf-8")
    changed = False
    missing = [p for p in ANDROID_PERMS if p not in text]
    if missing:
        lines = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in missing)
        idx = text.index("<manifest")
        end = text.index(">", idx) + 1
        text = text[:end] + "\n" + lines.rstrip("\n") + text[end:]
        changed = True
    if 'android:scheme="tel"' not in text:
        if "<queries>" in text:
            text = text.replace(
                "<queries>",
                '<queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW"/>\n            <data android:scheme="tel"/>\n        </intent>',
                1,
            )
        else:
            text = text.replace("<application", QUERIES + "    <application", 1)
        changed = True
    if changed:
        MANIFEST.write_text(text, encoding="utf-8")
        print("+ AndroidManifest.xml diperbarui")
    else:
        print("= AndroidManifest.xml sudah lengkap")
    return True


def patch_plist() -> bool:
    if not PLIST.exists():
        print(f"! {PLIST} tidak ada (lewati iOS).")
        return False
    text = PLIST.read_text(encoding="utf-8")
    changed = False
    add = ""
    for key, msg in PLIST_KEYS.items():
        if f"<key>{key}</key>" not in text:
            add += f"\t<key>{key}</key>\n\t<string>{msg}</string>\n"
    key, values = PLIST_QUERY
    if f"<key>{key}</key>" not in text:
        items = "".join(f"\t\t<string>{v}</string>\n" for v in values)
        add += f"\t<key>{key}</key>\n\t<array>\n{items}\t</array>\n"
    if add:
        pos = text.rindex("</dict>")
        text = text[:pos] + add + text[pos:]
        changed = True
    if changed:
        PLIST.write_text(text, encoding="utf-8")
        print("+ Info.plist diperbarui")
    else:
        print("= Info.plist sudah lengkap")
    return True


if __name__ == "__main__":
    ok = patch_manifest()
    patch_plist()
    sys.exit(0 if ok else 1)
