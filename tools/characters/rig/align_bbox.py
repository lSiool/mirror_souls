"""Совместить риг Mixamo с нашей моделью по габаритам (масштаб и сдвиг), сохранить."""
import bpy, sys
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--") + 1:]
ours_path, mix_path = argv
def bbox(ob):
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx
bpy.ops.wm.open_mainfile(filepath=ours_path)
omn, omx = bbox(bpy.data.objects["Werewolf_Young"])
bpy.ops.wm.open_mainfile(filepath=mix_path)
mix = bpy.data.objects["Werewolf_Young"]; rig = bpy.data.objects["Werewolf_Rig"]
mmn, mmx = bbox(mix)
s = (omx - omn).z / (mmx - mmn).z
print("OURS", [round(c, 3) for c in omn], [round(c, 3) for c in omx])
print("MIX ", [round(c, 3) for c in mmn], [round(c, 3) for c in mmx], "scale", round(s, 4))
# масштаб вокруг min-угла, потом сдвиг на наш min
T = Matrix.Translation(omn) @ Matrix.Scale(s, 4) @ Matrix.Translation(-mmn)
rig.matrix_world = T @ rig.matrix_world
if mix.parent != rig:
    mix.matrix_world = T @ mix.matrix_world
bpy.context.view_layer.update()
for o in bpy.context.view_layer.objects: o.select_set(o in (rig, mix))
bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
nmn, nmx = bbox(mix)
print("NEW ", [round(c, 3) for c in nmn], [round(c, 3) for c in nmx])
bpy.ops.wm.save_mainfile()
