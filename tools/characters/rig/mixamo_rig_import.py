"""Авториг Mixamo → наш формат: масштаб под рост, кости mixamorig_X, замер растяжения; сохранить .blend."""
import bpy, sys, math, collections
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
src, out_blend, height = argv[0], argv[1], float(argv[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.update()
zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
k = height / (max(zs) - min(zs))
arm.scale = arm.scale * k
bpy.context.view_layer.update()
for o in (arm, ob):
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
# стопы на пол, центр по X/Y — в ноль (Mixamo ставит модель центром в начало координат)
from mathutils import Matrix, Vector
pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
shift = Vector((-(min(p.x for p in pts) + max(p.x for p in pts)) / 2, -(min(p.y for p in pts) + max(p.y for p in pts)) / 2, -min(p.z for p in pts)))
arm.matrix_world = Matrix.Translation(shift) @ arm.matrix_world
if ob.parent != arm:
    ob.matrix_world = Matrix.Translation(shift) @ ob.matrix_world
bpy.context.view_layer.update()
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
for b in arm.data.bones:
    b.name = b.name.replace("mixamorig:", "mixamorig_")
arm.name = "Werewolf_Rig"; arm.data.name = "Werewolf_Rig"
ob.name = "Werewolf_Young"
zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
print("SCALE", round(k, 3), "HEIGHT", round(max(zs) - min(zs), 3), "MINZ", round(min(zs), 3))
B = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
for n in ("mixamorig_Hips", "mixamorig_Neck", "mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"):
    if n in B:
        print("BONE", n, [round(c, 3) for c in B[n][0]], [round(c, 3) for c in B[n][1]])
print("GROUPS", len(ob.vertex_groups))
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
