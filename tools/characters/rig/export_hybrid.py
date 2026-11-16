"""Гибрид → игра: материал из нашей модели, экспорт .glb (сетка + скелет, без анимаций)."""
import bpy, sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
hybrid, ours, out = argv
bpy.ops.wm.open_mainfile(filepath=hybrid)
with bpy.data.libraries.load(ours) as (src, dst):
    dst.objects = ["Werewolf_Young"]
ref = dst.objects[0]
ob = bpy.data.objects["Werewolf_Young"]; rig = bpy.data.objects["Werewolf_Rig"]
ob.data.materials.clear()
for m in ref.data.materials:
    ob.data.materials.append(m)
for p in ob.data.polygons:
    p.material_index = 0
print("UV", [uv.name for uv in ob.data.uv_layers], "MAT", [m.name for m in ob.data.materials])
mod = next((m for m in ob.modifiers if m.type == "ARMATURE"), None)
print("ARMMOD", mod and mod.object and mod.object.name, mod and mod.use_vertex_groups)
for pb in rig.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
bpy.ops.wm.save_mainfile()
for o in bpy.context.view_layer.objects: o.select_set(o in (ob, rig))
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False, export_skins=True, export_yup=True, export_apply=False)
print("EXPORTED", out, os.path.getsize(out))
