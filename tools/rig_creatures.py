"""Skin each static creature mesh and add idle, move, and attack clips."""
import json
import math
import os
import struct
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREATURES = os.path.join(ROOT, "assets", "models", "creatures")


def quat_axis(axis, angle):
    s = math.sin(angle * 0.5)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(angle * 0.5))


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_norm(q):
    n = math.sqrt(sum(c * c for c in q)) or 1.0
    return tuple(c / n for c in q)


def load_glb(path):
    data = open(path, "rb").read()
    off = 12
    jlen, _ = struct.unpack_from("<I4s", data, off)
    js = json.loads(data[off + 8 : off + 8 + jlen])
    off2 = off + 8 + jlen
    if off2 % 4:
        off2 += 4 - (off2 % 4)
    blen, _ = struct.unpack_from("<I4s", data, off2)
    blob = bytearray(data[off2 + 8 : off2 + 8 + blen])
    return js, blob


def save_glb(path, js, blob):
    js["buffers"] = [{"byteLength": len(blob)}]
    raw = json.dumps(js, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    blob = bytes(blob)
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(raw) + 8 + len(blob))
    out += struct.pack("<I4s", len(raw), b"JSON")
    out += raw
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    open(path, "wb").write(out)


def read_vec3(js, blob, acc_index):
    acc = js["accessors"][acc_index]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    pts = []
    for i in range(acc["count"]):
        pts.append(struct.unpack_from("<fff", blob, start + i * stride))
    return pts


def dist_segment(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    ap = (p[0] - a[0], p[1] - a[1], p[2] - a[2])
    denom = ab[0] * ab[0] + ab[1] * ab[1] + ab[2] * ab[2]
    t = 0.0 if denom < 1e-8 else max(0.0, min(1.0, (ap[0] * ab[0] + ap[1] * ab[1] + ap[2] * ab[2]) / denom))
    q = (a[0] + ab[0] * t, a[1] + ab[1] * t, a[2] + ab[2] * t)
    d = (p[0] - q[0], p[1] - q[1], p[2] - q[2])
    return math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2])


def bone(name, parent, pos, role, phase, swing):
    return {"name": name, "parent": parent, "pos": pos, "role": role, "phase": phase, "swing": swing}


def rig_for(kind):
    b = []

    def add(name, parent, pos, role, phase=0.0, swing=1.0):
        b.append(bone(name, parent, pos, role, phase, swing))
        return len(b) - 1

    root = add("root", -1, (0.0, 0.05, 0.0), "body")
    if kind == "01_ram_beetle":
        add("abdomen", root, (0.0, 0.02, -0.55), "body", 0.4, 0.6)
        thorax = add("thorax", root, (0.0, 0.08, 0.15), "body", 0.1, 0.4)
        add("head", thorax, (0.0, 0.16, 0.62), "head", 0.0, 0.8)
        add("horn", thorax, (0.0, 0.42, 0.78), "head", 0.2, 0.5)
        for i, z in enumerate((-0.32, 0.02, 0.34)):
            for s in (-1, 1):
                phase = i * 0.55 + (0.0 if s < 0 else 0.5)
                hip = add("hip_%d_%d" % (s, i), root, (0.28 * s, -0.12, z), "leg", phase, 1.0)
                knee = add("knee_%d_%d" % (s, i), hip, (0.52 * s, -0.42, z), "leg", phase, 1.15)
                add("foot_%d_%d" % (s, i), knee, (0.62 * s, -0.82, z + 0.08), "leg", phase, 0.8)
    elif kind == "02_smash_crab":
        add("shell", root, (0.0, 0.22, 0.05), "body", 0.0, 0.35)
        for s, name in ((-1, "L"), (1, "R")):
            arm = add(name + "_arm", root, (0.38 * s, 0.05, 0.18), "claw", 0.0 if s < 0 else 0.15, 1.0)
            claw = add(name + "_claw", arm, (0.68 * s, 0.12, 0.28), "claw", 0.1, 1.2)
            add(name + "_pincer", claw, (0.9 * s, 0.02, 0.38), "claw", 0.2, 1.3)
        for i, z in enumerate((-0.42, -0.08, 0.28)):
            for s in (-1, 1):
                phase = i * 0.45 + (0.0 if s < 0 else 0.5)
                hip = add("hip_%d_%d" % (s, i), root, (0.22 * s, -0.18, z), "leg", phase)
                add("foot_%d_%d" % (s, i), hip, (0.48 * s, -0.72, z - 0.12), "leg", phase, 1.1)
    elif kind == "03_iron_slug":
        prev = root
        for i, z in enumerate((-0.78, -0.42, -0.08, 0.28, 0.62)):
            prev = add("seg_%d" % i, prev, (0.0, -0.15 + i * 0.04, z), "slug", i * 0.35, 1.0)
        add("head", prev, (0.0, 0.08, 0.88), "head", 0.2, 0.7)
    elif kind == "04_manta_bat":
        add("body", root, (0.0, 0.02, 0.08), "body")
        add("tail", root, (0.0, -0.04, -0.55), "body", 0.4, 0.8)
        for s, name in ((-1, "L"), (1, "R")):
            inner = add(name + "_wing", root, (0.32 * s, 0.04, 0.02), "wing", 0.0, 1.0)
            mid = add(name + "_mid", inner, (0.62 * s, 0.0, 0.0), "wing", 0.15, 1.15)
            add(name + "_tip", mid, (0.92 * s, -0.06, -0.04), "wing", 0.3, 1.25)
    elif kind == "05_sting_wasp":
        abdomen = add("abdomen", root, (0.0, -0.08, -0.28), "body", 0.2, 0.7)
        add("sting", abdomen, (0.0, -0.22, -0.62), "head", 0.0, 1.0)
        thorax = add("thorax", root, (0.0, 0.08, 0.12), "body")
        add("head", thorax, (0.0, 0.16, 0.42), "head", 0.1, 0.6)
        for s, name in ((-1, "L"), (1, "R")):
            inner = add(name + "_wing", thorax, (0.28 * s, 0.28, 0.05), "wing")
            add(name + "_tip", inner, (0.72 * s, 0.34, 0.08), "wing", 0.2, 1.2)
            phase = 0.0 if s < 0 else 0.5
            hip = add(name + "_hip", root, (0.16 * s, -0.22, 0.02), "leg", phase, 0.7)
            add(name + "_foot", hip, (0.28 * s, -0.62, 0.08), "leg", phase, 0.8)
    else:
        add("body", root, (0.0, 0.12, 0.0), "body", 0.0, 0.4)
        add("head", root, (0.0, -0.05, 0.55), "head", 0.1, 0.8)
        for i in range(4):
            ang = -0.8 + i * 0.45
            z = math.sin(ang) * 0.15
            for s in (-1, 1):
                phase = i * 0.4 + (0.0 if s < 0 else 0.5)
                hip = add("hip_%d_%d" % (s, i), root, (0.28 * s, -0.05, z), "leg", phase)
                add("foot_%d_%d" % (s, i), hip, (0.62 * s, -0.55, z - 0.18), "leg", phase, 1.05)
    return b


def map_pos(npos, bounds):
    mn, mx = bounds
    out = []
    for i in range(3):
        mid = (mn[i] + mx[i]) * 0.5
        half = (mx[i] - mn[i]) * 0.5
        out.append(mid + npos[i] * half)
    return tuple(out)


def world_positions(bones, bounds):
    worlds = []
    for item in bones:
        local = map_pos(item["pos"], bounds)
        if item["parent"] < 0:
            worlds.append(local)
        else:
            parent = worlds[item["parent"]]
            worlds.append(local)
        item["world"] = worlds[-1]
        if item["parent"] < 0:
            item["local"] = worlds[-1]
        else:
            p = worlds[item["parent"]]
            item["local"] = tuple(worlds[-1][i] - p[i] for i in range(3))
    return worlds


def skin_weights(points, bones):
    joints = []
    weights = []
    worlds = [b["world"] for b in bones]
    for p in points:
        scored = []
        for i, b in enumerate(bones):
            if b["parent"] < 0:
                d = math.dist(p, worlds[i])
            else:
                d = dist_segment(p, worlds[b["parent"]], worlds[i])
            scored.append((d, i))
        scored.sort()
        pick = scored[:4]
        raw = []
        ids = []
        for d, i in pick:
            raw.append(1.0 / (d * d + 0.012))
            ids.append(i)
        while len(ids) < 4:
            ids.append(0)
            raw.append(0.0)
        total = sum(raw) or 1.0
        weights.append(tuple(w / total for w in raw))
        joints.append(tuple(ids))
    return joints, weights


def clip_rotation(bone, t, clip):
    phase = bone["phase"] * math.tau
    swing = bone["swing"]
    role = bone["role"]
    w = t * math.tau
    if clip == "idle":
        amp = 0.08 * swing
        if role == "wing":
            amp = 0.18
        if role in ("leg", "claw"):
            amp = 0.12 * swing
        ang = math.sin(w + phase) * amp
    elif clip == "attack":
        ang = math.sin(w * 2.0) * (0.55 if role in ("claw", "head", "leg") else 0.2) * swing
    else:
        ang = math.sin(w * 2.0 + phase) * (0.55 if role in ("leg", "claw", "slug") else 0.22) * swing
        if role == "wing":
            ang = math.sin(w * 6.0 + phase) * 0.7 * swing
    side = -1.0 if "L" in bone["name"] or bone["name"].startswith("hip_-") or bone["name"].startswith("knee_-") or bone["name"].startswith("foot_-") else 1.0
    if role == "wing":
        return quat_norm(quat_axis((0.0, 0.0, side), ang))
    if role in ("leg", "claw"):
        lift = abs(math.sin(w * 2.0 + phase)) * 0.35 * swing
        return quat_norm(quat_mul(quat_axis((0.0, 1.0, 0.0), ang * side), quat_axis((0.0, 0.0, side), lift)))
    if role == "slug":
        return quat_norm(quat_axis((0.0, 1.0, 0.0), ang))
    return quat_norm(quat_axis((1.0, 0.0, 0.0), ang * 0.45))


def align(blob):
    while len(blob) % 4:
        blob.append(0)


def add_view(js, blob, data, target=None):
    align(blob)
    offset = len(blob)
    blob.extend(data)
    view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
    if target is not None:
        view["target"] = target
    js["bufferViews"].append(view)
    return len(js["bufferViews"]) - 1


def add_accessor(js, view, count, ctype, atype, extra=None):
    acc = {"bufferView": view, "componentType": ctype, "count": count, "type": atype}
    if extra:
        acc.update(extra)
    js["accessors"].append(acc)
    return len(js["accessors"]) - 1


def build(kind, path):
    js, blob = load_glb(path)
    prim = js["meshes"][0]["primitives"][0]
    points = read_vec3(js, blob, prim["attributes"]["POSITION"])
    mn = js["accessors"][prim["attributes"]["POSITION"]]["min"]
    mx = js["accessors"][prim["attributes"]["POSITION"]]["max"]
    bones = rig_for(kind)
    world_positions(bones, (mn, mx))
    joint_ids, weight_vals = skin_weights(points, bones)
    joint_bytes = bytearray()
    for ids in joint_ids:
        joint_bytes.extend(bytes(ids))
    weight_bytes = bytearray()
    for w in weight_vals:
        weight_bytes.extend(struct.pack("<ffff", *w))
    jview = add_view(js, blob, joint_bytes)
    wview = add_view(js, blob, weight_bytes)
    jacc = add_accessor(js, jview, len(points), 5121, "VEC4")
    wacc = add_accessor(js, wview, len(points), 5126, "VEC4")
    prim["attributes"]["JOINTS_0"] = jacc
    prim["attributes"]["WEIGHTS_0"] = wacc

    ibm = bytearray()
    for b in bones:
        x, y, z = b["world"]
        ibm.extend(struct.pack("<16f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1))
    ibm_view = add_view(js, blob, ibm)
    ibm_acc = add_accessor(js, ibm_view, len(bones), 5126, "MAT4")

    mesh_node = len(js["nodes"])
    js["nodes"].append({"name": "Body", "mesh": 0, "skin": 0})
    joint_nodes = []
    for b in bones:
        node = {"name": b["name"], "translation": list(b["local"])}
        js["nodes"].append(node)
        joint_nodes.append(len(js["nodes"]) - 1)
    for i, b in enumerate(bones):
        kids = [joint_nodes[k] for k, other in enumerate(bones) if other["parent"] == i]
        if kids:
            js["nodes"][joint_nodes[i]]["children"] = kids
    root = {"name": "Armature", "children": [mesh_node, joint_nodes[0]]}
    js["nodes"].append(root)
    root_index = len(js["nodes"]) - 1
    js["skins"] = [{"name": kind, "joints": joint_nodes, "inverseBindMatrices": ibm_acc, "skeleton": joint_nodes[0]}]
    js["scenes"] = [{"nodes": [root_index]}]
    js["scene"] = 0

    times = [i / 8.0 for i in range(9)]
    time_bytes = struct.pack("<%df" % len(times), *times)
    time_view = add_view(js, blob, time_bytes)
    time_acc = add_accessor(js, time_view, len(times), 5126, "SCALAR", {"min": [times[0]], "max": [times[-1]]})
    animations = []
    for clip in ("idle", "move", "attack"):
        channels = []
        samplers = []
        for i, b in enumerate(bones):
            keys = [clip_rotation(b, t, "move" if clip == "move" else clip) for t in times]
            if clip == "move" and b["role"] == "wing":
                keys = [clip_rotation(b, t, "move") for t in times]
            raw = bytearray()
            for q in keys:
                raw.extend(struct.pack("<ffff", *q))
            view = add_view(js, blob, raw)
            acc = add_accessor(js, view, len(keys), 5126, "VEC4")
            samplers.append({"input": time_acc, "output": acc, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": joint_nodes[i], "path": "rotation"}})
        animations.append({"name": clip, "channels": channels, "samplers": samplers})
    if kind in ("04_manta_bat", "05_sting_wasp", "06_bloated_tick"):
        move = animations[1]
        animations.append({"name": "fly", "channels": move["channels"], "samplers": move["samplers"]})
    js["animations"] = animations
    save_glb(path, js, blob)
    print(kind, "bones", len(bones), "verts", len(points), "bytes", os.path.getsize(path))


def main():
    for name in sorted(os.listdir(CREATURES)):
        if not name.endswith(".glb"):
            continue
        build(name[:-4], os.path.join(CREATURES, name))


if __name__ == "__main__":
    main()
