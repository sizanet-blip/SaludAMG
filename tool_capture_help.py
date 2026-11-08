"""Captura pantallas de ayuda de SaludAMG desde el emulador (adb)."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ADB = Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe"
OUT = Path(r"d:\Proyectos\flutter\SaludAMG\assets\help")
DUMP = Path.home() / "AppData/Local/Temp/uidump.xml"
TMP = Path.home() / "AppData/Local/Temp/salud_shot.png"

OUT.mkdir(parents=True, exist_ok=True)


def adb(*args, timeout=60):
    return subprocess.run(
        [str(ADB), *args],
        capture_output=True,
        timeout=timeout,
    )


def dump_ui() -> str:
    adb("shell", "rm", "-f", "/sdcard/uidump.xml")
    adb("shell", "uiautomator", "dump", "/sdcard/uidump.xml")
    adb("pull", "/sdcard/uidump.xml", str(DUMP))
    return DUMP.read_text(encoding="utf-8", errors="ignore")


def nodes(xml: str):
    found = []
    for m in re.finditer(r"<node [^>]*>", xml):
        tag = m.group(0)
        text = re.search(r'text="([^"]*)"', tag)
        desc = re.search(r'content-desc="([^"]*)"', tag)
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
        raw = (desc.group(1) if desc else "") or (text.group(1) if text else "")
        raw = raw.replace("&#10;", "\n")
        # Primera línea (cabeceras) + texto completo (tiles agrupados).
        primary = raw.split("\n")[0].strip()
        full = " ".join(part.strip() for part in raw.split("\n") if part.strip())
        if not primary or not bounds:
            continue
        x1, y1, x2, y2 = map(int, bounds.groups())
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        found.append((primary, cx, cy, y1, y2, full))
    return found


def tap_label(label: str, partial: bool = True) -> bool:
    xml = dump_ui()
    for item in nodes(xml):
        primary, x, y = item[0], item[1], item[2]
        full = item[5] if len(item) > 5 else primary
        if partial:
            ok = label in primary or label in full
        else:
            ok = primary == label or full == label
        if ok:
            adb("shell", "input", "tap", str(x), str(y))
            time.sleep(1.1)
            return True
    print("NO TAP", label)
    return False


def scroll_down() -> None:
    adb("shell", "input", "swipe", "540", "1500", "540", "700", "250")
    time.sleep(0.4)


def shot(name: str) -> None:
    """Guarda PNG válido (cmd redirect evita corrupción en Windows)."""
    dest = OUT / name
    if TMP.exists():
        TMP.unlink()
    cmd = f'"{ADB}" exec-out screencap -p > "{TMP}"'
    subprocess.run(cmd, shell=True, check=True)
    data = TMP.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        data = data.replace(b"\r\n", b"\n")
    dest.write_bytes(data)
    print("saved", name, dest.stat().st_size)


def back(n: int = 1) -> None:
    for _ in range(n):
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.55)


def go_home_menu() -> None:
    """Vuelve al menú principal (Inicio) con varios Atrás."""
    for _ in range(6):
        xml = dump_ui()
        labels = " | ".join(t for t, *_ in nodes(xml)[:40])
        if "Resumen" in labels and "Configuración" in labels and "Ayuda" in labels:
            return
        back(1)
    time.sleep(0.4)


def capture_auth() -> None:
    print("--- auth ---")
    tap_label("Entrar")
    time.sleep(0.4)
    shot("02_saludamg_login.png")

    tap_label("Crear")
    time.sleep(0.4)
    shot("03_saludamg_registro.png")

    if tap_label("privacidad") or tap_label("Privacidad"):
        time.sleep(0.5)
        shot("04_saludamg_privacidad.png")
        back()

    if tap_label("condiciones") or tap_label("Condiciones"):
        time.sleep(0.5)
        shot("05_saludamg_condiciones.png")
        back()

    # Recuperar contraseña: enlace por email (desde la pantalla de acceso).
    tap_label("Ya tengo cuenta") or back()
    time.sleep(0.4)
    if tap_label("Olvidé"):
        time.sleep(0.4)
        shot("06_saludamg_recuperar.png")
        tap_label("Ya tengo cuenta") or back()


def _open_from_home(label: str) -> bool:
    go_home_menu()
    time.sleep(0.3)
    if tap_label(label):
        return True
    scroll_down()
    return tap_label(label)


def _open_config_item(label: str) -> bool:
    if not _open_from_home("Configuración"):
        return False
    time.sleep(0.4)
    if tap_label(label):
        return True
    scroll_down()
    return tap_label(label)


def capture_app_screens() -> None:
    print("--- app ---")
    time.sleep(1.0)
    go_home_menu()

    if tap_label("Datos de prueba"):
        time.sleep(1.5)

    go_home_menu()
    shot("01_saludamg_home.png")

    if _open_from_home("Resumen"):
        time.sleep(0.7)
        shot("27_saludamg_resumen.png")
        back()

    if _open_from_home("Historial"):
        time.sleep(0.6)
        shot("08_saludamg_historial.png")
        back()

    if _open_from_home("Medicaciones"):
        time.sleep(0.6)
        shot("10_saludamg_medicaciones.png")
        # «Tomado» pregunta la hora real (se cancela: no guarda nada).
        if tap_label("Tomado", partial=False):
            time.sleep(0.6)
            shot("29_saludamg_tomado_hora.png")
            tap_label("Cancelar", partial=False)
        back()

    if _open_from_home("Configuración"):
        time.sleep(0.5)
        shot("28_saludamg_config.png")
        back()

    config_shots = [
        ("Ficha", "07_saludamg_ficha.png"),
        ("Recordatorios", "09_saludamg_recordatorios.png"),
        ("Datos a medir", "12_saludamg_datos_medir.png"),
        ("Opciones de medicación", "11_saludamg_med_config.png"),
        ("Copia de seguridad", "13_saludamg_backup.png"),
        ("Bloqueo", "14_saludamg_bloqueo.png"),
        ("Acerca de", "16_saludamg_acerca.png"),
    ]
    for label, file in config_shots:
        print("config", label)
        if label == "Acerca de":
            if not _open_from_home("Configuración"):
                print(" skip", label)
                continue
            time.sleep(0.3)
            for _ in range(6):
                adb("shell", "input", "swipe", "540", "1700", "540", "500", "250")
                time.sleep(0.25)
            if not (tap_label("Acerca de") or tap_label("Acerca")):
                # Última fila bajo «Cuenta y app»
                adb("shell", "input", "tap", "540", "2200")
                time.sleep(0.8)
            time.sleep(0.5)
            shot(file)
            back(2)
            continue
        if not _open_config_item(label):
            print(" skip", label)
            continue
        time.sleep(0.6)
        shot(file)
        back(2)

    if _open_from_home("Ayuda"):
        time.sleep(0.5)
        shot("15_saludamg_ayuda.png")
        if tap_label("Guía rápida"):
            time.sleep(0.5)
            shot("17_saludamg_guia.png")
            back()
        if tap_label("Manual completo"):
            time.sleep(0.5)
            shot("18_saludamg_manual.png")
            back()
        if tap_label("Preguntas"):
            time.sleep(0.5)
            shot("19_saludamg_faq.png")
            back()
        # Legal (mismas pantallas que en registro)
        if tap_label("Privacidad") or tap_label("privacidad"):
            time.sleep(0.5)
            shot("04_saludamg_privacidad.png")
            back()
        if tap_label("Condiciones") or tap_label("condiciones"):
            time.sleep(0.5)
            shot("05_saludamg_condiciones.png")
            back()
        back()

    go_home_menu()
    if tap_label("Medición"):
        time.sleep(0.7)
        shot("20_saludamg_medicion.png")
        back()

    if _open_from_home("Resumen"):
        time.sleep(0.5)
        # Menú ⋮ de Resumen → Exportar
        xml = dump_ui()
        for cand in ("Más opciones", "More options", "Show menu"):
            for text, x, y, *_ in nodes(xml):
                if cand.lower() in text.lower():
                    adb("shell", "input", "tap", str(x), str(y))
                    time.sleep(0.6)
                    break
            else:
                continue
            break
        else:
            adb("shell", "input", "tap", "990", "200")
            time.sleep(0.6)
        if tap_label("Exportar Excel"):
            time.sleep(0.7)
            shot("21_saludamg_exportar_informe.png")
            # Columnas: desplazar un poco el diálogo
            adb("shell", "input", "swipe", "540", "1400", "540", "700", "250")
            time.sleep(0.4)
            shot("22_saludamg_exportar_columnas.png")
            back()
        back()


def main():
    import sys

    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("auth", "all"):
        capture_auth()
    if mode in ("app", "all"):
        capture_app_screens()
    print("done ->", OUT)


if __name__ == "__main__":
    main()
