"""Wordmark SaludAMG: plantilla TiroAMG con línea idéntica (recta tras el escalón)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TIRO = Path(r'd:\Proyectos\flutter\TiroAMG\assets\tiroamg_wordmark.png')
ICON = ROOT / 'assets' / 'branding' / 'saludamg-app-icon.png'
OUT = ROOT / 'assets' / 'branding' / 'saludamg-wordmark.png'
PREVIEW = ROOT / 'tmp_new_wordmark_preview.png'
COMPARE = ROOT / 'tmp_wordmark_compare.png'

ORANGE = (255, 140, 26)
INK = (55, 65, 80)
TAG = (82, 82, 82)
ICON_W = 246
# Franja de la línea en el PNG de Tiro (tras el escalón queda horizontal).
LINE_Y0, LINE_Y1 = 180, 210


def _rounded_icon(src: Image.Image, size: int, radius: int) -> Image.Image:
  icon = src.convert('RGBA').resize((size, size), Image.Resampling.LANCZOS)
  mask = Image.new('L', (size, size), 0)
  ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, size - 1, size - 1), radius=radius, fill=255
  )
  out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
  out.paste(icon, (0, 0), mask)
  return out


def _is_cyan(r: int, g: int, b: int, a: int) -> bool:
  return a > 60 and b > 150 and g > 110 and r < 130 and b >= r + 40


def _is_reddish(r: int, g: int, b: int, a: int) -> bool:
  return a > 30 and r > 130 and r >= g + 25 and r >= b + 25 and b < 140


def main() -> None:
  original = Image.open(TIRO).convert('RGBA')
  base = original.copy()
  w, h = base.size
  px = base.load()

  # Guardar la franja de la línea EXACTA de Tiro antes de tocar tipografía.
  line_strip = base.crop((ICON_W, LINE_Y0, w, LINE_Y1)).copy()

  # 1) Icono Salud.
  for y in range(h):
    for x in range(ICON_W):
      px[x, y] = (0, 0, 0, 0)
  icon = _rounded_icon(Image.open(ICON), size=250, radius=48)
  base.alpha_composite(icon, ((ICON_W - 250) // 2, (h - 250) // 2))
  px = base.load()

  # 2) Inicio de AMG (cian en franja del nombre, por encima de la línea).
  amg_x = w
  for y in range(50, 165):
    for x in range(ICON_W + 40, w):
      r, g, b, a = px[x, y]
      if a > 160 and b > 195 and g > 155 and r < 90:
        amg_x = min(amg_x, x)

  # 3) Borrar «Tiro» (solo encima de la línea).
  for y in range(35, LINE_Y0):
    for x in range(ICON_W, amg_x):
      r, g, b, a = px[x, y]
      if a < 8 or _is_cyan(r, g, b, a):
        continue
      px[x, y] = (0, 0, 0, 0)

  # 4) Borrar tagline (debajo de la línea).
  for y in range(LINE_Y1, h):
    for x in range(ICON_W, w):
      r, g, b, a = px[x, y]
      if a < 8:
        continue
      px[x, y] = (0, 0, 0, 0)

  # 5) Restaurar franja de línea intacta de Tiro.
  base.paste(line_strip, (ICON_W, LINE_Y0))
  px = base.load()

  # 6) Solo recolorear rojo → naranja DENTRO de la franja de línea.
  #    No desplazar AMG: evita romper la horizontalidad.
  for y in range(LINE_Y0, LINE_Y1):
    for x in range(ICON_W, w):
      r, g, b, a = px[x, y]
      if not _is_reddish(r, g, b, a):
        continue
      t = min(1.0, max(0.45, (r - 90) / 165.0))
      px[x, y] = (
        int(ORANGE[0] * t + r * (1 - t)),
        int(ORANGE[1] * t + g * (1 - t)),
        int(ORANGE[2] * t + b * (1 - t)),
        a,
      )

  draw = ImageDraw.Draw(base)

  # 7) «Salud» en el hueco de «Tiro».
  text_left = 272
  max_w = amg_x - text_left - 4
  font = None
  text_w = text_h = 0
  for size in range(104, 28, -1):
    candidate = ImageFont.truetype(r'C:\Windows\Fonts\arialbd.ttf', size)
    bbox = draw.textbbox((0, 0), 'Salud', font=candidate)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    if tw <= max_w:
      font, text_w, text_h = candidate, tw, th
      break
  assert font is not None
  text_y = 52 + (100 - text_h) // 2
  draw.text((text_left, text_y), 'Salud', font=font, fill=(*INK, 255))
  print(f'Salud size={font.size} w={text_w} amg_x={amg_x}')

  # 8) Tagline (mismo tono que Tiro).
  tag_font = ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf', 22)
  draw.text((278, 216), 'Tensión · pulso · peso', font=tag_font, fill=(*TAG, 255))

  # Comprobar que la cota alta de la línea es plana (misma Y dominante).
  high_ys: list[int] = []
  for y in range(LINE_Y0, LINE_Y1):
    for x in range(ICON_W + 80, w - 40):
      r, g, b, a = px[x, y]
      if a < 120:
        continue
      if _is_cyan(r, g, b, a) or (
        a > 80 and r > 160 and 70 < g < 190 and b < 100
      ):
        high_ys.append(y)
  if high_ys:
    from collections import Counter

    mode_y, count = Counter(high_ys).most_common(1)[0]
    spread = max(high_ys) - min(high_ys)
    print(f'line high mode_y={mode_y} count={count} spread={spread}')

  bbox = base.getbbox()
  assert bbox is not None
  pad = 2
  cropped = base.crop(
    (
      max(0, bbox[0] - pad),
      max(0, bbox[1] - pad),
      min(w, bbox[2] + pad),
      min(h, bbox[3] + pad),
    )
  )
  cropped.save(OUT)
  print(f'saved {OUT} {cropped.size}')

  # Actualizar constantes en el widget Dart.
  title = ROOT / 'lib' / 'presentation' / 'widgets' / 'salud_amg_app_bar_title.dart'
  src = title.read_text(encoding='utf-8')
  import re

  src2 = re.sub(
    r'static const double assetWidth = \d+;',
    f'static const double assetWidth = {cropped.width};',
    src,
  )
  src2 = re.sub(
    r'static const double assetHeight = \d+;',
    f'static const double assetHeight = {cropped.height};',
    src2,
  )
  if src2 != src:
    title.write_text(src2, encoding='utf-8')
    print('updated asset size constants')

  gap = 36
  compare = Image.new(
    'RGBA',
    (
      max(cropped.width, original.width) + 48,
      original.height + cropped.height + gap + 48,
    ),
    (244, 246, 248, 255),
  )
  compare.alpha_composite(original, (24, 24))
  compare.alpha_composite(cropped, (24, 24 + original.height + gap))
  compare.save(COMPARE)
  preview = Image.new(
    'RGBA',
    (cropped.width + 48, cropped.height + 48),
    (244, 246, 248, 255),
  )
  preview.alpha_composite(cropped, (24, 24))
  preview.save(PREVIEW)


if __name__ == '__main__':
  main()
