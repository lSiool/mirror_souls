"""Сцены врагов леса и босса (graybox): крыса, мародёры, утопленник, призрак тумана, Кузнец.

Запуск из корня проекта: python tools/levels/build_enemies.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from scenery import box_mesh, box_shape, collision_node, enemy_scene, hitbox_nodes, hurtbox_nodes, material, mesh_node, node3d  # noqa: E402


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


# ---------------------------------------------------------------- Крыса
def rat():
    subs = [material("Mat_fur", (0.17, 0.15, 0.14)), material("Mat_tail", (0.42, 0.33, 0.32)),
            material("Mat_eye", (0.55, 1.0, 0.35), 3.0),
            box_shape("Shape_body", (1.0, 0.45, 0.6)), box_mesh("Mesh_body", (0.95, 0.38, 0.46)),
            box_mesh("Mesh_hump", (0.55, 0.24, 0.42), "Mat_fur"), box_mesh("Mesh_skull", (0.32, 0.24, 0.28), "Mat_fur"),
            box_mesh("Mesh_snout", (0.22, 0.12, 0.16), "Mat_fur"), box_mesh("Mesh_ear", (0.06, 0.12, 0.1), "Mat_tail"),
            box_mesh("Mesh_eye", (0.05, 0.04, 0.3), "Mat_eye"), box_mesh("Mesh_leg", (0.08, 0.18, 0.08), "Mat_fur"),
            box_shape("Shape_attack", (0.9, 0.7, 1.0)), box_shape("Shape_tail", (1.3, 0.8, 1.0)), box_shape("Shape_hurt", (1.15, 0.8, 1.0))]
    for i in range(5):
        subs.append(box_mesh(f"Mesh_tail{i}", (0.3, 0.07 - i * 0.01, 0.07 - i * 0.01), "Mat_tail"))
    nodes = [collision_node("Shape_body", 0.225), '[node name="Visual" type="Node3D" parent="."]',
             mesh_node("Body", "Visual", "Mesh_body", (0, 0.26, 0)), mesh_node("Hump", "Visual", "Mesh_hump", (-0.12, 0.5, 0)),
             node3d("Head", "Visual", (0.5, 0.28, 0)), mesh_node("Skull", "Visual/Head", "Mesh_skull", (0.1, 0, 0)),
             mesh_node("Snout", "Visual/Head", "Mesh_snout", (0.32, -0.05, 0)), mesh_node("EarA", "Visual/Head", "Mesh_ear", (0.02, 0.17, 0.1)),
             mesh_node("EarB", "Visual/Head", "Mesh_ear", (0.02, 0.17, -0.1)), mesh_node("Eye", "Visual/Head", "Mesh_eye", (0.2, 0.05, 0))]
    for i, (x, z) in enumerate(((0.28, 0.16), (0.28, -0.16), (-0.28, 0.16), (-0.28, -0.16))):
        name = "Leg" + "ABCD"[i]
        nodes += [node3d(name, "Visual", (x, 0.16, z)), mesh_node("Paw", f"Visual/{name}", "Mesh_leg", (0, -0.07, 0))]
    parent = "Visual"
    nodes.append(node3d("Tail", parent, (-0.47, 0.3, 0)))
    parent = "Visual/Tail"
    for i in range(5):
        nodes.append(mesh_node("Seg", parent, f"Mesh_tail{i}", (-0.15, 0, 0)))
        if i < 4:
            nodes.append(node3d("Link", parent, (-0.3, 0, 0)))
            parent += "/Link"
    nodes += [hitbox_nodes("Visual", "Shape_attack", (0.6, 0.35, 0), 8.0, 4.0),
              hitbox_nodes("Visual", "Shape_tail", (-0.95, 0.35, 0), 6.0, 5.0, "TailHitbox"), hurtbox_nodes("Shape_hurt", 0.4)]
    props = """patrol_distance = 2.0
patrol_speed = 1.6
chase_speed = 4.4
detect_range = 7.0
back_sense_range = 2.5
attack_range = 1.3
windup_time = 0.32
attack_time = 0.2
recover_time = 0.55
stagger_time = 0.3
attack_lunge = 6.0
body_color = Color(0.2, 0.17, 0.16, 1)
max_poise = 12.0
turn_time = 0.12
backstab_allowed = false
parry_allowed = false
hurt_voice = &""
death_voice = &""
echoes = 6
mastery_xp = 0.5"""
    write("actors/enemies/rat.tscn", enemy_scene("res://actors/enemies/rat.gd", '[node name="Rat" type="CharacterBody3D"]\ncollision_layer = 4\ncollision_mask = 3',
                                                 "\n\n".join(subs), 25.0, props, "\n\n".join(nodes)))


# ---------------------------------------------------------------- Мародёры
def bandit(kind):
    heavy = kind == "heavy"
    subs = [material("Mat_cloth", (0.2, 0.17, 0.13)), material("Mat_hood", (0.12, 0.1, 0.09)), material("Mat_skin", (0.45, 0.35, 0.28)),
            material("Mat_silver", (0.75, 0.75, 0.8), 0.4), material("Mat_sack", (0.38, 0.3, 0.2)),
            box_shape("Shape_body", (0.7, 1.75, 0.6)), box_mesh("Mesh_body", (0.62, 1.15, 0.45)),
            box_mesh("Mesh_legs", (0.5, 0.65, 0.4), "Mat_cloth"), box_mesh("Mesh_head", (0.3, 0.32, 0.3), "Mat_skin"),
            box_mesh("Mesh_hood", (0.4, 0.38, 0.4), "Mat_hood"),
            box_mesh("Mesh_prop", (0.1, 1.1, 0.1) if heavy else (0.5, 0.06, 0.06), "Mat_silver"),
            box_mesh("Mesh_prop_top", (0.4, 0.12, 0.12), "Mat_silver"), box_mesh("Mesh_sack", (0.55, 0.6, 0.45), "Mat_sack"),
            box_shape("Shape_attack", (1.5, 1.4, 1.2) if heavy else (1.2, 1.2, 1.0)), box_shape("Shape_hurt", (0.9, 1.9, 1.0))]
    nodes = [collision_node("Shape_body", 0.875), '[node name="Visual" type="Node3D" parent="."]',
             mesh_node("Body", "Visual", "Mesh_body", (0, 1.22, 0)), mesh_node("Legs", "Visual", "Mesh_legs", (0, 0.33, 0)),
             mesh_node("Head", "Visual", "Mesh_head", (0.04, 1.97, 0)), mesh_node("Hood", "Visual", "Mesh_hood", (-0.02, 2.0, 0))]
    if heavy:
        nodes += [mesh_node("Prop", "Visual", "Mesh_prop", (0.45, 1.3, 0.3), 0.5), mesh_node("PropTop", "Visual", "Mesh_prop_top", (0.72, 1.78, 0.3), 0.5)]
    else:
        nodes += [mesh_node("Prop", "Visual", "Mesh_prop", (0.5, 1.15, 0.3)), mesh_node("Sack", "Visual", "Mesh_sack", (-0.45, 1.4, -0.1), 0.3)]
    nodes += [hitbox_nodes("Visual", "Shape_attack", (0.85, 1.1, 0), 16.0 if heavy else 10.0, 6.0 if heavy else 3.0), hurtbox_nodes("Shape_hurt", 0.95)]
    props = f"""kind = {0 if heavy else 1}
dormant = true
patrol_distance = 0.0
chase_speed = {3.6 if heavy else 4.2}
detect_range = 12.0
back_sense_range = 4.0
attack_range = {1.9 if heavy else 1.5}
windup_time = 0.6
attack_time = 0.2
recover_time = 0.7
stagger_time = 0.4
attack_lunge = 5.0
body_color = Color({"0.24, 0.19, 0.15" if heavy else "0.18, 0.17, 0.15"}, 1)
max_poise = {45 if heavy else 30}.0
turn_time = 0.25
echoes = 45
mastery_xp = 1.5"""
    name = "BanditHeavy" if heavy else "BanditKnife"
    write(f"actors/enemies/bandit_{kind}.tscn", enemy_scene("res://actors/enemies/bandit.gd",
          f'[node name="{name}" type="CharacterBody3D"]\ncollision_layer = 4\ncollision_mask = 3', "\n\n".join(subs), 90.0 if heavy else 70.0,
          props, "\n\n".join(nodes)))


# ---------------------------------------------------------------- Утопленник
def drowned_knight():
    subs = [material("Mat_bone", (0.62, 0.58, 0.5)), material("Mat_rust", (0.25, 0.2, 0.13)), material("Mat_moss", (0.17, 0.22, 0.1)),
            material("Mat_shroom", (0.75, 0.6, 0.4), 0.8), material("Mat_blade", (0.45, 0.42, 0.4)),
            box_shape("Shape_body", (0.75, 1.9, 0.6)), box_mesh("Mesh_body", (0.7, 1.15, 0.5)),
            box_mesh("Mesh_legs", (0.42, 0.75, 0.32), "Mat_bone"), box_mesh("Mesh_skull", (0.32, 0.36, 0.3), "Mat_bone"),
            box_mesh("Mesh_helm", (0.4, 0.22, 0.38), "Mat_rust"), box_mesh("Mesh_shield", (0.12, 1.05, 0.85), "Mat_rust"),
            box_mesh("Mesh_moss", (0.14, 0.5, 0.6), "Mat_moss"), box_mesh("Mesh_reed", (0.04, 0.7, 0.04), "Mat_moss"),
            box_mesh("Mesh_shroom", (0.14, 0.08, 0.14), "Mat_shroom"), box_mesh("Mesh_blade", (1.3, 0.09, 0.06), "Mat_blade"),
            box_shape("Shape_attack", (1.9, 1.4, 1.2)), box_shape("Shape_hurt", (0.95, 2.0, 1.0))]
    nodes = [collision_node("Shape_body", 0.95), '[node name="Visual" type="Node3D" parent="."]',
             mesh_node("Body", "Visual", "Mesh_body", (0, 1.3, 0)), mesh_node("Legs", "Visual", "Mesh_legs", (0, 0.38, 0)),
             mesh_node("Skull", "Visual", "Mesh_skull", (0.05, 2.08, 0)), mesh_node("Helm", "Visual", "Mesh_helm", (0.0, 2.25, 0)),
             mesh_node("ReedA", "Visual", "Mesh_reed", (-0.25, 2.1, 0.15), 0.3), mesh_node("ReedB", "Visual", "Mesh_reed", (-0.1, 2.15, -0.1), -0.2),
             mesh_node("Shroom", "Visual", "Mesh_shroom", (-0.2, 1.9, 0.2)),
             node3d("Shield", "Visual", (0.45, 1.15, 0.12)), mesh_node("Plate", "Visual/Shield", "Mesh_shield", (0, 0, 0)),
             mesh_node("Moss", "Visual/Shield", "Mesh_moss", (0.07, -0.2, 0)),
             node3d("Blade", "Visual", (0.2, 1.35, -0.2)), mesh_node("Sword", "Visual/Blade", "Mesh_blade", (0.65, 0, 0)),
             hitbox_nodes("Visual", "Shape_attack", (1.1, 1.2, 0), 16.0, 5.0), hurtbox_nodes("Shape_hurt", 1.0)]
    props = """dormant = true
patrol_distance = 1.5
chase_speed = 3.4
detect_range = 12.0
back_sense_range = 3.0
attack_range = 2.1
windup_time = 0.35
attack_time = 0.2
recover_time = 0.55
stagger_time = 0.45
attack_lunge = 9.0
body_color = Color(0.2, 0.19, 0.13, 1)
max_poise = 70.0
poise_regen = 20.0
turn_time = 0.25
hurt_voice = &""
death_voice = &"enemy_death_voice"
echoes = 80
mastery_xp = 2.5
weapon_type = &"sword\""""
    write("actors/enemies/drowned_knight.tscn", enemy_scene("res://actors/enemies/drowned_knight.gd",
          '[node name="DrownedKnight" type="CharacterBody3D"]\ncollision_layer = 4\ncollision_mask = 3', "\n\n".join(subs), 160.0, props, "\n\n".join(nodes)))


# ---------------------------------------------------------------- Призрак тумана
def fog_wraith():
    subs = [material("Mat_wing", (0.1, 0.1, 0.14), alpha=0.3), material("Mat_eye", (0.75, 0.95, 1.0), 4.0),
            box_shape("Shape_body", (0.6, 0.6, 0.6)), box_mesh("Mesh_body", (0.45, 0.8, 0.35)),
            box_mesh("Mesh_wing", (0.9, 0.06, 0.5), "Mat_wing"), box_mesh("Mesh_eye", (0.08, 0.06, 0.4), "Mat_eye"),
            box_shape("Shape_attack", (1.0, 1.0, 1.0)), box_shape("Shape_hurt", (1.4, 1.2, 1.0))]
    nodes = [collision_node("Shape_body", 0), '[node name="Visual" type="Node3D" parent="."]', mesh_node("Body", "Visual", "Mesh_body", (0, 0, 0)),
             mesh_node("WingLeft", "Visual", "Mesh_wing", (-0.6, 0.15, 0)), mesh_node("WingRight", "Visual", "Mesh_wing", (0.6, 0.15, 0)),
             mesh_node("EyeA", "Visual", "Mesh_eye", (0.12, 0.25, 0)), mesh_node("EyeB", "Visual", "Mesh_eye", (-0.04, 0.25, 0)),
             hitbox_nodes("Visual", "Shape_attack", (0, 0, 0), 14.0, 5.0), hurtbox_nodes("Shape_hurt", 0)]
    props = """body_color = Color(0.08, 0.08, 0.12, 0.3)
windup_time = 0.5
attack_time = 0.55
recover_time = 0.6
backstab_allowed = false
parry_allowed = false
hurt_voice = &""
death_voice = &""
echoes = 25
mastery_xp = 1.0
wake_range_x = 9.0
wake_range_y = 6.0
hover_height = 2.2
hover_speed = 5.0
dive_speed = 12.0"""
    write("actors/enemies/fog_wraith.tscn", enemy_scene("res://actors/enemies/fog_wraith.gd",
          '[node name="FogWraith" type="CharacterBody3D"]\ncollision_layer = 0\ncollision_mask = 1', "\n\n".join(subs), 30.0, props, "\n\n".join(nodes)))


# ---------------------------------------------------------------- Безмолвный Кузнец
def blacksmith():
    subs = [material("Mat_iron", (0.32, 0.31, 0.33)), material("Mat_wood", (0.2, 0.13, 0.08)), material("Mat_scar", (0.16, 0.14, 0.15)),
            material("Mat_eye", (0.75, 0.35, 1.0), 5.0),
            box_shape("Shape_body", (1.3, 2.8, 1.0)), box_mesh("Mesh_body", (1.6, 2.3, 1.1)),
            box_mesh("Mesh_shoulders", (2.0, 0.6, 1.2), "Mat_scar"), box_mesh("Mesh_skull", (0.55, 0.6, 0.55), "Mat_scar"),
            box_mesh("Mesh_eye", (0.1, 0.07, 0.6), "Mat_eye"), box_mesh("Mesh_handle", (0.16, 2.2, 0.16), "Mat_wood"),
            box_mesh("Mesh_head", (1.1, 0.7, 0.7), "Mat_iron"), box_shape("Shape_attack", (3.0, 2.6, 4.0)), box_shape("Shape_hurt", (1.7, 3.0, 1.2))]
    nodes = [collision_node("Shape_body", 1.4),
             '[node name="Visual" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.15)',
             mesh_node("Body", "Visual", "Mesh_body", (0, 1.15, 0)), mesh_node("Shoulders", "Visual", "Mesh_shoulders", (-0.1, 2.35, 0)),
             node3d("Head", "Visual", (0.35, 2.85, 0)), mesh_node("Skull", "Visual/Head", "Mesh_skull", (0, 0, 0)),
             mesh_node("EyeA", "Visual/Head", "Mesh_eye", (0.24, 0.06, 0)), mesh_node("EyeB", "Visual/Head", "Mesh_eye", (0.1, 0.06, 0)),
             node3d("Hammer", "Visual", (0.8, 2.0, 0.75)), mesh_node("Handle", "Visual/Hammer", "Mesh_handle", (0, 1.0, 0)),
             mesh_node("Head", "Visual/Hammer", "Mesh_head", (0, 2.05, 0)),
             hitbox_nodes("Visual", "Shape_attack", (2.0, 1.2, 0), 22.0, 8.0), hurtbox_nodes("Shape_hurt", 1.5)]
    props = """body_color = Color(0.24, 0.22, 0.24, 1)
hurt_voice = &""
death_voice = &""
detect_range = 13.0
back_sense_range = 2.5
chase_speed = 2.2
attack_range = 3.3
recover_time = 1.0
stagger_time = 0.4
max_poise = 300.0
poise_regen = 30.0
off_balance_time = 2.4
turn_time = 1.0
backstab_allowed = false
parry_allowed = false
roll_through = true
windup_tint = 0.2
echoes = 0
mastery_xp = 6.0
weapon_type = &"hammer\""""
    write("actors/enemies/blacksmith.tscn", enemy_scene("res://actors/enemies/blacksmith.gd",
          '[node name="Blacksmith" type="CharacterBody3D"]\ncollision_layer = 4\ncollision_mask = 3', "\n\n".join(subs), 800.0, props, "\n\n".join(nodes)))


rat()
bandit("heavy")
bandit("knife")
drowned_knight()
fog_wraith()
blacksmith()
print("ok")
