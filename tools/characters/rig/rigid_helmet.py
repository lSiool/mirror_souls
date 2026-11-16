"""Шлем жёстко на кость головы: выше z1 — Head 1.0, от z0 до z1 — плавный переход."""
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
path, z0, z1, half_x = argv[0], float(argv[1]), float(argv[2]), float(argv[3])
bpy.ops.wm.open_mainfile(filepath=path)
ob = bpy.data.objects["Werewolf_Young"]; M = ob.matrix_world
head = ob.vertex_groups["mixamorig_Head"]; gi = {g.index: g for g in ob.vertex_groups}
n = 0
for v in ob.data.vertices:
    p = M @ v.co
    if p.z < z0 or abs(p.x) > half_x or not (-0.17 < p.y < 0.14):
        continue
    t = min(1.0, (p.z - z0) / (z1 - z0))
    w = {g.group: g.weight for g in v.groups}
    hw = w.get(head.index, 0.0)
    new_h = hw + (1.0 - hw) * t
    rest = 1.0 - hw
    for g in list(v.groups):
        if g.group != head.index:
            gi[g.group].add([v.index], (g.weight / rest) * (1.0 - new_h) if rest > 1e-6 else 0.0, "REPLACE")
    head.add([v.index], new_h, "REPLACE")
    n += 1
bpy.ops.wm.save_mainfile()
print("RIGID", n)
