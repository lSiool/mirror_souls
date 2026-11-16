"""Сгладить веса на шее и плечах: полоса вокруг границы головы (Head) и вокруг шва рука↔шея."""
import bpy, bmesh, sys
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=argv[0])
ob = bpy.data.objects["Werewolf_Young"]; me = ob.data; M = ob.matrix_world
gi = {g.index: g.name for g in ob.vertex_groups}
def dom(v): return gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else ""
D = {v.index: dom(v) for v in me.vertices}
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seam = set()
for e in bm.edges:
    a, b = e.verts
    da, db = D[a.index], D[b.index]
    if da != db and (M @ a.co).z > 1.4 and ("Head" in (da + db) or "Neck" in (da + db)):
        seam.update((a.index, b.index))
band = set(seam)
for _ in range(3):
    band |= {e.other_vert(bm.verts[i]).index for i in list(band) for e in bm.verts[i].link_edges}
bm.free()
for v in me.vertices: v.select = v.index in band
for o in bpy.context.view_layer.objects: o.select_set(False)
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="WEIGHT_PAINT"); me.use_paint_mask_vertex = True
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=5, expand=0.0)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
me.use_paint_mask_vertex = False; bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_mainfile()
print("SMOOTHED", len(seam), len(band))
