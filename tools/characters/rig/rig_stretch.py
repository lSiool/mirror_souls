"""Замер рига в Blender (фон): растяжение рёбер в позах + главные кости в области. Аргументы: blend [face]"""
import bpy, sys, math, collections
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
ob = bpy.data.objects["Werewolf_Young"]; rig = bpy.data.objects["Werewolf_Rig"]; me = ob.data; M = ob.matrix_world
gi = {g.index: g.name.replace("mixamorig_", "") for g in ob.vertex_groups}
def dom(v):
    return gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "-"
# морда: перед шеей и выше плеч
face = collections.Counter(); n = 0
for v in me.vertices:
    p = M @ v.co
    if p.z > 1.5 and p.y < 0.02:
        face[dom(v)] += 1; n += 1
print("FACE", n, face.most_common(8))
rest = [v.co.copy() for v in me.vertices]
edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
P = {
 "head_down": {"Head": ("X", 30)}, "head_up": {"Head": ("X", -30)}, "head_turn": {"Head": ("Y", 35)},
 "neck": {"Neck": ("X", 25), "Head": ("X", 20)},
 "raise": {"LeftArm": ("X", -60), "RightArm": ("X", -60)}, "fwd": {"LeftArm": ("Z", 60), "RightArm": ("Z", -60)},
 "bend": {"LeftForeArm": ("X", -70), "RightForeArm": ("X", -70)},
 "twist": {"LeftForeArm": ("Y", 60), "RightForeArm": ("Y", -60)},
 "leg": {"LeftUpLeg": ("X", -50), "LeftLeg": ("X", 60)},
}
for pb in rig.pose.bones: pb.rotation_mode = "QUATERNION"
for name, pose in P.items():
    for pb in rig.pose.bones: pb.rotation_quaternion = (1, 0, 0, 0)
    for b, (ax, deg) in pose.items():
        pb = rig.pose.bones.get("mixamorig_" + b)
        if pb: pb.rotation_quaternion = Quaternion(Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[ax]), math.radians(deg))
    bpy.context.view_layer.update(); dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg); m = ev.to_mesh(); co = [v.co.copy() for v in m.vertices]; ev.to_mesh_clear()
    bad = []
    for a, b in edges:
        r = (rest[a] - rest[b]).length
        if r < 1e-4: continue
        s = (co[a] - co[b]).length / r
        if s > 2.0: bad.append((s, a, b))
    bad.sort(reverse=True)
    top = [(round(s, 1), [round(c, 2) for c in M @ rest[a]], dom(me.vertices[a]), dom(me.vertices[b])) for s, a, b in bad[:3]]
    print("POSE", name, len(bad), round(bad[0][0], 1) if bad else 0, top)
