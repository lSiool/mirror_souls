"""Глаза в модель: две светящиеся сферы в глазницах шлема, привязаны к кости головы.
Аргументы: blend x_left x_right z y_front радиус — м модели (замер глубины шлема лучами спереди)."""
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
path = argv[0]; xl, xr, z, y, r = map(float, argv[1:6])
bpy.ops.wm.open_mainfile(filepath=path)
rig = bpy.data.objects["Werewolf_Rig"]
old = bpy.data.objects.get("Smith_Eyes")
if old: bpy.data.objects.remove(old)
parts = []
for x in (xl, xr):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=(x, y, z))
    parts.append(bpy.context.active_object)
for o in bpy.context.view_layer.objects: o.select_set(o in parts)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
eyes = bpy.context.active_object; eyes.name = "Smith_Eyes"; eyes.data.name = "Smith_Eyes"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mat = bpy.data.materials.new("Smith_Eyes_Mat"); mat.use_nodes = True
b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
b.inputs["Base Color"].default_value = (0.3, 0.15, 0.7, 1.0)
b.inputs["Emission Color"].default_value = (0.3, 0.15, 0.7, 1.0)
b.inputs["Emission Strength"].default_value = 1.0
eyes.data.materials.append(mat)
g = eyes.vertex_groups.new(name="mixamorig_Head"); g.add(list(range(len(eyes.data.vertices))), 1.0, "REPLACE")
eyes.parent = rig; eyes.matrix_parent_inverse = rig.matrix_world.inverted()
m = eyes.modifiers.new("Armature", "ARMATURE"); m.object = rig; m.use_vertex_groups = True
bpy.ops.wm.save_mainfile()
print("EYES", len(eyes.data.vertices), [round(c, 3) for c in (xl, xr, z, y, r)])
