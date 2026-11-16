import bpy, sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
mode, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
if mode == "blend":
    ob = bpy.data.objects["Werewolf_Young"]
    for m in ob.modifiers:
        m.show_viewport = False
    rig = bpy.data.objects.get("Werewolf_Rig")
    if rig:
        rig.data.pose_position = "REST"
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=argv[2])
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    ob = meshes[0]
for mat in ob.data.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                name = bpy.path.clean_name(img.name) + ".png"
                img.filepath_raw = os.path.join(out, name)
                img.file_format = "PNG"
                img.save()
for o in bpy.context.view_layer.objects:
    o.select_set(False)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.wm.obj_export(filepath=os.path.join(out, "werewolf.obj"), export_selected_objects=True, apply_modifiers=False,
                      export_materials=True, path_mode="STRIP", export_uv=True, export_normals=True, forward_axis="NEGATIVE_Z", up_axis="Y")
print("EXPORTED", out, len(ob.data.vertices))
