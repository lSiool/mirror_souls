"""Клипы Mixamo на манекене героя (§3.3, §6.1, 2026-11-14): карта костей и настройки импорта.

Mixamo (Y Bot) отдаёт скелет с костями mixamorig_Hips, mixamorig_Spine1, mixamorig_LeftForeArm…
При импорте Godot переименовывает их в стандартный гуманоидный профиль (SkeletonProfileHumanoid),
как и клипы Quaternius (setup_mannequin.py), — и клипы ложатся на манекен героя и врагов.

Клипы — в assets/characters/anims/mixamo/ (папка в .gitignore: исходные FBX Mixamo по лицензии
Adobe нельзя выкладывать в открытый доступ; что из них берём в игру и где храним — решает автор).
Скачанные наборы и отдельные клипы лежат в D:\\Downloads\\mixamo.

Запуск из корня проекта: python tools/characters/setup_mixamo.py
Потом импорт: "/c/Program Files/Godot/Godot.exe" --headless --path . --import
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLIPS = ROOT / "assets" / "characters" / "anims" / "mixamo"
BONE_MAP = ROOT / "assets" / "characters" / "mannequin" / "mixamo_bone_map.tres"
PREFIX = "mixamorig_"

# Кость профиля → кость Mixamo (без префикса). Корня у Mixamo нет — кость профиля Root пустая.
BODY = {
    "Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2",
    "Neck": "Neck", "Head": "Head",
}
LIMBS = {
    "Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "ForeArm", "Hand": "Hand",
    "UpperLeg": "UpLeg", "LowerLeg": "Leg", "Foot": "Foot", "Toes": "ToeBase",
}
FINGERS = {
    "ThumbMetacarpal": "HandThumb1", "ThumbProximal": "HandThumb2", "ThumbDistal": "HandThumb3",
    "IndexProximal": "HandIndex1", "IndexIntermediate": "HandIndex2", "IndexDistal": "HandIndex3",
    "MiddleProximal": "HandMiddle1", "MiddleIntermediate": "HandMiddle2", "MiddleDistal": "HandMiddle3",
    "RingProximal": "HandRing1", "RingIntermediate": "HandRing2", "RingDistal": "HandRing3",
    "LittleProximal": "HandPinky1", "LittleIntermediate": "HandPinky2", "LittleDistal": "HandPinky3",
}


def bone_map() -> dict[str, str]:
    bones = {profile: PREFIX + mixamo for profile, mixamo in BODY.items()}
    for side in ("Left", "Right"):
        for part, mixamo in {**LIMBS, **FINGERS}.items():
            bones[side + part] = PREFIX + side + mixamo
    return bones


def write_bone_map() -> None:
    lines = [
        '[gd_resource type="BoneMap" load_steps=2 format=3]',
        "",
        '[sub_resource type="SkeletonProfileHumanoid" id="SkeletonProfileHumanoid_1"]',
        "",
        "[resource]",
        'profile = SubResource("SkeletonProfileHumanoid_1")',
    ]
    lines += [f'bone_map/{profile} = &"{bone}"' for profile, bone in bone_map().items()]
    BONE_MAP.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def patch_import(path: Path) -> bool:
    """Карта костей на скелет клипа; клипы без обрезки (как у Quaternius). False — импорта ещё нет."""
    text = path.read_text(encoding="utf-8")
    sub = (
        '_subresources={\n"nodes": {\n"PATH:Skeleton3D": {\n'
        '"retarget/bone_map": Resource("res://assets/characters/mannequin/mixamo_bone_map.tres")\n'
        "}\n}\n}"
    )
    start = text.index("_subresources=")
    end = text.index("\nfbx/", start)
    text = text[:start] + sub + text[end:]
    text = text.replace("animation/trimming=true", "animation/trimming=false")
    path.write_text(text, encoding="utf-8", newline="\n")
    return True


if __name__ == "__main__":
    write_bone_map()
    imports = sorted(CLIPS.glob("*.fbx.import"))
    for item in imports:
        patch_import(item)
    print("ok:", BONE_MAP.relative_to(ROOT), "+", len(imports), "clips")
