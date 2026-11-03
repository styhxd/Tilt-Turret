import fs from "fs";
import path from "path";
import { NodeIO } from "@gltf-transform/core";
import { dedup, prune, simplify, textureCompress, weld } from "@gltf-transform/functions";
import { MeshoptSimplifier } from "meshoptimizer";
import sharp from "sharp";

const root = process.argv[2];
const io = new NodeIO();

async function run(kind, size, ratio) {
  const srcDir = path.join(root, "assets_src", "meshy", kind);
  const dstDir = path.join(root, "assets", "models", kind);
  fs.mkdirSync(dstDir, { recursive: true });
  for (const folder of fs.readdirSync(srcDir)) {
    const src = path.join(srcDir, folder, `${folder}.glb`);
    if (!fs.existsSync(src)) {
      console.log("skip", src);
      continue;
    }
    const dst = path.join(dstDir, `${folder}.glb`);
    console.log("optimize", folder);
    const doc = await io.read(src);
    for (const mat of doc.getRoot().listMaterials()) {
      mat.setNormalTexture(null);
      mat.setOcclusionTexture(null);
      mat.setMetallicRoughnessTexture(null);
      mat.setMetallicFactor(0.12);
      mat.setRoughnessFactor(0.78);
    }
    await doc.transform(
      weld(),
      simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.02 }),
      prune(),
      dedup(),
      textureCompress({
        encoder: sharp,
        targetFormat: "jpeg",
        resize: [size, size],
        quality: 80,
      })
    );
    await io.write(dst, doc);
    console.log(" wrote", folder, Math.round(fs.statSync(dst).size / 1024) + "KB");
  }
}

await MeshoptSimplifier.ready;
await run("modules", 1024, 0.38);
await run("creatures", 512, 0.4);
console.log("done");
