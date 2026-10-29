# Портреты VN

Утверждённый базовый лист: `approved-bases.png` (1536 × 1024, шесть образов, по три колонки; верхняя строка смотрит вправо, нижняя — влево).

Эмоциональные атласы: `grat-emotions.png`, `grok-emotions.png`, `jbt-emotions.png`. Каждый лист — прозрачный PNG 4 × 4. Колонки в строках: neutral, happy, sad, angry; в следующей строке: surprised, afraid, embarrassed, neutral-дубликат. Строки 0–1 предназначены для левой стороны и взгляда вправо, строки 2–3 — для правой стороны и взгляда влево. Последняя ячейка каждой пары оставлена как нейтральный запасной кадр.

Общий production prompt для каждого листа:

> Production visual-novel portrait atlas, transparent PNG, exact 4 by 4 grid of sixteen equal cells, one consistent waist-up character in every cell, same scale and crop, generous transparent margins, clean polished semi-realistic digital illustration, no background, no text, no props, no extra people. Row 1: left placement facing screen-right, neutral, happy, sad, angry. Row 2: left placement facing screen-right, surprised, afraid, embarrassed, neutral duplicate. Row 3: right placement facing screen-left, neutral, happy, sad, angry. Row 4: right placement facing screen-left, surprised, afraid, embarrassed, neutral duplicate. Preserve the approved character identity, clothing, proportions, asymmetrical details and logos in every cell; do not mirror asymmetrical details.

Дополнения к образам:

- Grat: stocky/chubby young man, broad torso and softer belly, rounded tired ordinary face, messy bleached hair with dark roots, light stubble, oversized off-white short-sleeve shirt over a white long-sleeve high-neck shirt.
- Grok: angular adult woman, sharp brows, dark-wine eyeliner, long black wolf cut with a burgundy streak on the anatomical left, septum and left eyebrow piercings, burgundy scoop-neck top, open black leather jacket, choker, white orbital-X patch on the anatomical left chest.
- JBT: adult woman with soft round face, light freckles, grey-green eyes, thin round glasses, short wavy white bob, small hair clip on the anatomical right, ivory scoop-neck tee, open mint cardigan and centered mint circle badge with a white knot.

Интеграция не делает `flip_h`: `scripts/vn_dialogue.gd` выбирает отдельную строку атласа для каждой стороны и добавляет небольшой inset региона, чтобы линейная фильтрация не подтягивала соседний кадр.
