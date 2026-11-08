"""Манекен героя (§3.3, 2026-11-09): карта костей и настройки импорта.

Анимации Quaternius (Universal Animation Library 1 и 2, CC0) сделаны на скелете в стиле
Unreal (pelvis, spine_01, hand_r…). При импорте Godot переименовывает кости в стандартный
гуманоидный профиль (SkeletonProfileHumanoid: Hips, Spine, RightHand…) по карте костей,
и анимации ложатся на любую модель с тем же профилем — так потом переносим их на модель автора.

Запуск из корня проекта: python tools/characters/setup_mannequin.py
Потом импорт: "/c/Program Files/Godot/Godot.exe" --headless --path . --import
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets" / "characters" / "mannequin"
BONE_MAP = DIR / "ue_bone_map.tres"
MODELS = ["ual1.glb", "ual2.glb"]

# Кость профиля → кость скелета в стиле Unreal (у Quaternius и в Universal Base Characters).
BODY = {
    "Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02",
    "UpperChest": "spine_03", "Neck": "neck_01", "Head": "Head",
}
FINGERS = {
    "ThumbMetacarpal": "thumb_01", "ThumbProximal": "thumb_02", "ThumbDistal": "thumb_03",
    "IndexProximal": "index_01", "IndexIntermediate": "index_02", "IndexDistal": "index_03",
    "MiddleProximal": "middle_01", "MiddleIntermediate": "middle_02", "MiddleDistal": "middle_03",
    "RingProximal": "ring_01", "RingIntermediate": "ring_02", "RingDistal": "ring_03",
    "LittleProximal": "pinky_01", "LittleIntermediate": "pinky_02", "LittleDistal": "pinky_03",
}
LIMBS = {
    "Shoulder": "clavicle", "UpperArm": "upperarm", "LowerArm": "lowerarm", "Hand": "hand",
    "UpperLeg": "thigh", "LowerLeg": "calf", "Foot": "foot", "Toes": "ball",
}


def bone_map() -> dict[str, str]:
    bones = dict(BODY)
    for side, suffix in (("Left", "_l"), ("Right", "_r")):
        for part, ue in {**LIMBS, **FINGERS}.items():
            bones[side + part] = ue + suffix
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
    lines += [f'bone_map/{profile} = &"{ue}"' for profile, ue in bone_map().items()]
    BONE_MAP.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def patch_import(name: str) -> None:
    path = DIR / (name + ".import")
    text = path.read_text(encoding="utf-8")
    sub = (
        '_subresources={\n"nodes": {\n"PATH:Armature/Skeleton3D": {\n'
        '"retarget/bone_map": Resource("res://assets/characters/mannequin/ue_bone_map.tres")\n'
        "}\n}\n}"
    )
    start = text.index("_subresources=")
    end = text.index("\ngltf/", start)
    text = text[:start] + sub + text[end:]
    path.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    write_bone_map()
    for model in MODELS:
        patch_import(model)
    print("ok:", BONE_MAP.relative_to(ROOT), "+", ", ".join(MODELS))
