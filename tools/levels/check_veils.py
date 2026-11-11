"""Проверка комнат: слой тумана (QuadMesh) не должен лежать в плоскости грани декора-коробки.

Полупрозрачный слой и грань спорят за глубину — декор за туманом мерцает (корни «Стены леса»,
2026-11-11). Запуск из корня проекта: python tools/levels/check_veils.py — печатает совпадения;
пусто — всё чисто.
"""
import glob
import re
for f in sorted(glob.glob('world/rooms/*.tscn')):
    t=open(f,encoding='utf-8').read().replace('\r\n','\n')
    quads={m.group(1):[float(v) for v in m.group(2).split(',')] for m in re.finditer(r'\[sub_resource type="QuadMesh" id="([^"]+)"\][^\[]*?size = Vector2\(([^)]+)\)',t)}
    nodes=re.split(r'\n(?=\[node )',t)
    veils=[];solids=[]
    for n in nodes:
        m=re.match(r'\[node name="([^"]+)" type="(\w+)"',n)
        if not m: continue
        pos=re.search(r'\nposition = Vector3\(([^)]+)\)',n)
        if not pos: continue
        p=[float(v) for v in pos.group(1).split(',')]
        rot=re.search(r'\nrotation = Vector3\(([^)]+)\)',n)
        r=[float(v) for v in rot.group(1).split(',')] if rot else [0,0,0]
        if m.group(2)=='MeshInstance3D':
            q=re.search(r'mesh = SubResource\("([^"]+)"\)',n)
            if q and q.group(1) in quads: veils.append((m.group(1),p,quads[q.group(1)]))
        elif m.group(2)=='CSGBox3D':
            sz=[float(v) for v in re.search(r'\nsize = Vector3\(([^)]+)\)',n).group(1).split(',')]
            if abs(r[0])<1e-3 and abs(r[1])<1e-3: solids.append((m.group(1),p,sz))
        elif m.group(2)=='CSGCylinder3D':
            rad=float(re.search(r'radius = ([\d.]+)',n).group(1)); h=float(re.search(r'height = ([\d.]+)',n).group(1))
    for vn,vp,vs in veils:
        for sn,sp,ss in solids:
            ext=max(ss[0],ss[1])  # повёрнутые вокруг Z — берём с запасом
            for face in (sp[2]-ss[2]/2, sp[2]+ss[2]/2):
                if abs(face-vp[2])<0.03 and abs(sp[0]-vp[0])<vs[0]/2+ext/2 and abs(sp[1]-vp[1])<vs[1]/2+ext/2:
                    print(f.split('/')[-1], vn, 'z=%.2f'%vp[2], '~', sn)
