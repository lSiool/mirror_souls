"""Гибрид: риг и веса тела — Mixamo; морда — веса нашего рига; перемычки рука↔нога — удалить."""
import bpy, bmesh, sys
from mathutils import kdtree
argv = sys.argv[sys.argv.index("--") + 1:]
ours_path, mix_path, out_path = argv
bpy.ops.wm.open_mainfile(filepath=mix_path)
mix = bpy.data.objects["Werewolf_Young"]
with bpy.data.libraries.load(ours_path) as (src, dst):
    dst.objects = ["Werewolf_Young"]
ours = dst.objects[0]; ours.name = "Ours_Ref"
bpy.context.scene.collection.objects.link(ours)
Mm, Mo = mix.matrix_world, ours.matrix_world
# соответствие вершин по положению (порядок мог измениться при OBJ)
kd = kdtree.KDTree(len(ours.data.vertices))
for v in ours.data.vertices: kd.insert(Mo @ v.co, v.index)
kd.balance()
match = []; far = 0
for v in mix.data.vertices:
    co, i, d = kd.find(Mm @ v.co)
    match.append(i); far += d > 0.003
print("MATCH far>3mm:", far, "of", len(match))
gm = {g.name: g for g in mix.vertex_groups}
go = {g.index: g.name for g in ours.vertex_groups}
gmi = {g.index: g.name for g in mix.vertex_groups}
def dom(v, names):
    return names[max(v.groups, key=lambda g: g.weight).group] if v.groups else ""
# 1) морда: где у нашего рига главная кость — Head, берём наши веса (кости головы/шеи)
HEADSET = {"mixamorig_Head", "mixamorig_Neck"}
face = []
for v in mix.data.vertices:
    o = ours.data.vertices[match[v.index]]
    p = Mm @ v.co
    if p.z > 1.45 and dom(o, go) == "mixamorig_Head":
        face.append(v.index)
        for g in list(v.groups): mix.vertex_groups[g.group].remove([v.index])
        ws = {go[g.group]: g.weight for g in o.groups if go[g.group] in gm}
        tot = sum(ws.values()) or 1.0
        for n, w in ws.items(): gm[n].add([v.index], w / tot, "REPLACE")
print("FACE copied", len(face))
# 2) перемычки: грани, где у вершин главная кость руки и главная кость ноги
gmi = {g.index: g.name for g in mix.vertex_groups}
arms = {"mixamorig_%s%s" % (s, b) for s in ("Left", "Right") for b in ("Shoulder", "Arm", "ForeArm", "Hand")}
legs = {"mixamorig_%s%s" % (s, b) for s in ("Left", "Right") for b in ("UpLeg", "Leg", "Foot", "ToeBase")}
D = {v.index: dom(v, gmi) for v in mix.data.vertices}
bridge = [p.index for p in mix.data.polygons if any(D[i] in arms for i in p.vertices) and any(D[i] in legs for i in p.vertices)]
bm = bmesh.new(); bm.from_mesh(mix.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in bridge], context="FACES_ONLY")
bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(mix.data); bm.free(); mix.data.update()
print("BRIDGE faces deleted", len(bridge))
# 3) перекрёстные веса рука↔нога убрать, сгладить шов морды
gmi = {g.index: g.name for g in mix.vertex_groups}
clean = 0
for v in mix.data.vertices:
    if not v.groups: continue
    w = {gmi[g.group]: g.weight for g in v.groups}
    d = max(w, key=w.get)
    drop = arms if d in legs else legs if d in arms else set()
    if any(n in drop for n in w):
        keep = {n: x for n, x in w.items() if n not in drop}; s = sum(keep.values())
        for g in list(v.groups): mix.vertex_groups[g.group].remove([v.index])
        for n, x in keep.items(): gm[n].add([v.index], x / s, "REPLACE")
        clean += 1
print("CROSS cleaned", clean)
bpy.data.objects.remove(ours)
for o in bpy.context.view_layer.objects: o.select_set(False)
mix.select_set(True); bpy.context.view_layer.objects.active = mix
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_as_mainfile(filepath=out_path)
print("SAVED", out_path)
