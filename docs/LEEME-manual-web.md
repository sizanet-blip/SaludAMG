# Manual web (CMS)

## 1. Sube las imágenes
Copia todos los PNG de `assets/help/` a la carpeta del panel:

`/uploads/cms/`

(ruta en la web: `/uploads/cms/`)

**Mismo nombre de archivo** (ej. `01_saludamg_home.png`).

Lista:

- `00_saludamg_icono.png`
- `01_saludamg_home.png` — menú principal (acciones + entradas)
- `02_saludamg_login.png`
- `03_saludamg_registro.png`
- `04_saludamg_privacidad.png`
- `05_saludamg_condiciones.png`
- `06_saludamg_recuperar.png`
- `07_saludamg_ficha.png`
- `08_saludamg_historial.png`
- `09_saludamg_recordatorios.png`
- `10_saludamg_medicaciones.png`
- `11_saludamg_med_config.png`
- `12_saludamg_datos_medir.png`
- `13_saludamg_backup.png`
- `14_saludamg_bloqueo.png`
- `15_saludamg_ayuda.png`
- `16_saludamg_acerca.png`
- `17_saludamg_guia.png`
- `18_saludamg_manual.png`
- `19_saludamg_faq.png`
- `20_saludamg_medicion.png`
- `21_saludamg_exportar_informe.png`
- `22_saludamg_exportar_columnas.png`
- `23_saludamg_exportar_excel_share.png`
- `24_saludamg_exportar_pdf_share.png`
- `25_saludamg_informe_pdf.png`
- `26_saludamg_informe_pdf_detalle.png`
- `27_saludamg_resumen.png` — dashboard (última toma / evolución)
- `28_saludamg_config.png` — hub de configuración
- `29_saludamg_tomado_hora.png` — «Tomado»: elegir la hora real de la toma
- `30_saludamg_desbloqueo.png` — pantalla de desbloqueo (PIN / huella)

## 2. Pega el HTML
Abre `docs/manual-web-cms.html`, selecciona todo, copia y pégalo en el campo **contenido** del CMS (modo código/HTML si existe).

## 3. Regenerar capturas (emulador)
Con el emulador en marcha:

Compila con el panel local y entra con una cuenta de pruebas
(`tool/cuenta-pruebas.local.json`, no se sube a git):

```bash
# En Android + *.desarrollo la app usa el puente 10.0.2.2 (como TiroAMG).
# Móvil físico: --dart-define=LICENSE_DEV_HOST=192.168.x.x
flutter run -d emulator-5554 --dart-define=APP_AUTH_API_URL=https://panel.amg.desarrollo/

# Pantallas de acceso: con la sesión cerrada
python tool_capture_help.py auth

# Pantallas de la app: con la sesión iniciada. Para «Pendientes de ayer»,
# restaura antes una copia con una medicación que empiece días atrás.
python tool_capture_help.py app
```

`30_saludamg_desbloqueo.png` se hace a mano: pon un PIN en Configuración → Bloqueo,
sal de la app y vuelve a abrirla.

## 4. Guarda y revisa la web del programa
Comprueba que las capturas (200 px de ancho) se ven bien en la página publicada.
