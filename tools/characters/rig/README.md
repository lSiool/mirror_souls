# Авториг персонажа (Mixamo) и гибрид весов — скрипты Blender

Запуск: `"/d/Blender/blender.exe" -b [файл.blend] --python tools/characters/rig/<скрипт>.py -- <аргументы>`.
Порядок (оборотень, 2026-11-17; подробно — docs/CHARACTER_PIPELINE.md §4а):

1. `export_obj.py blend <папка>` — модель без скелета → OBJ + текстуры; упаковать в ZIP, загрузить в Mixamo (Upload Character), расставить маркеры, скачать FBX «Original Pose» (дождаться конца загрузки — размер перестал расти).
2. `mixamo_rig_import.py <fbx> <out.blend> <рост>` — масштаб (Mixamo принимает метры за сантиметры), кости `mixamorig:X` → `mixamorig_X`, объекты Werewolf_Rig / Werewolf_Young.
3. `align_bbox.py <наш.blend> <mixamo.blend>` — совместить с нашей моделью по габаритам (Mixamo ставит стопы на ноль и центрирует).
4. `rig_stretch.py <blend>` — замер: растяжение рёбер в позах (голова, руки, локоть, нога) и главные кости морды. Сравнить наш риг и Mixamo.
5. `hybrid_rig.py <наш.blend> <mixamo.blend> <out.blend>` — скелет и тело от Mixamo, морда (где у нашего главная кость Head) — наши веса; перемычки рука↔нога удалить.
6. `smooth_seam.py <out.blend>` — сгладить шов шеи и плеч; снова `rig_stretch.py`.
7. `export_hybrid.py <out.blend> <наш.blend> <out.glb>` — материал из нашей модели, экспорт .glb в assets/characters/<id>/.

Имена объектов (Werewolf_Young, Werewolf_Rig) — пока под оборотня; для нового персонажа — поправить в скриптах или переименовать объекты.
