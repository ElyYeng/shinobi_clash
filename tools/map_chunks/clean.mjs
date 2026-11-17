// Step 1: clean the ripped map without changing what it looks like.
// - drops the old game's sky dome and the 12 km ground plane (the game has its own sky)
// - removes duplicate textures / materials / meshes / data
// - bakes every object's transform so each node sits directly in world space (needed for chunking)
// - caps texture size: 2048 px for big ground textures, 1024 px for everything else
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, flatten, prune, textureCompress } from '@gltf-transform/functions';
import sharp from 'sharp';

const [src, out] = process.argv.slice(2);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(src);
const root = doc.getRoot();

const DROP = [/^sky\d*/i, /^plane01/i];
let dropped = 0;
for (const node of root.listNodes()) {
  if (DROP.some((re) => re.test(node.getName()))) {
    node.dispose();
    dropped++;
  }
}
console.log('dropped backdrop nodes:', dropped);

await doc.transform(dedup(), flatten(), prune({ keepSolidTextures: true }));

const GROUND = /gart|ground|plain|floor|grass|terrain/i;
const groundTex = new Set();
for (const mat of root.listMaterials()) {
  const t = mat.getBaseColorTexture();
  if (t && GROUND.test(mat.getName())) groundTex.add(t);
}
// tag ground textures by name so the 2048 pass can target them
for (const t of root.listTextures()) {
  if (groundTex.has(t)) t.setName('GROUND__' + (t.getName() || t.getURI() || 'tex'));
}
await doc.transform(
  textureCompress({ encoder: sharp, resize: [2048, 2048], pattern: /^GROUND__/ }),
  textureCompress({ encoder: sharp, resize: [1024, 1024], pattern: /^(?!GROUND__)/ }),
  prune({ keepSolidTextures: true }),   // (never drop "flat" textures: grass cards are flat colour + alpha)
);

// Rip fixes:
//  - grass materials whose texture is a 1x1 white pixel (the Blender colour didn't export): grass green
//  - materials whose base colour alpha is 0 but have a real texture: alpha 1 (the texture's alpha decides)
let grassFixed = 0, alphaFixed = 0;
const grassMats = new Set();
for (const node of root.listNodes()) {
  if (/^grass/i.test(node.getName()) && node.getMesh()) {
    for (const prim of node.getMesh().listPrimitives()) if (prim.getMaterial()) grassMats.add(prim.getMaterial());
  }
}
for (const mat of root.listMaterials()) {
  const tex = mat.getBaseColorTexture();
  const size = tex ? tex.getSize() : null;
  if (grassMats.has(mat) && size && size[0] <= 4 && size[1] <= 4) {
    mat.setBaseColorTexture(null);
    mat.setBaseColorFactor([0.30, 0.48, 0.18, 1]);
    mat.setAlphaMode('OPAQUE');
    grassFixed++;
  } else if (tex && mat.getAlpha() <= 0.001 && size && size[0] > 4) {
    mat.setAlpha(1);
    alphaFixed++;
  }
}
console.log('grass materials coloured', grassFixed, '| alpha-0 materials made visible', alphaFixed);

// Blender exports every material as BLEND (slow, no depth sorting, no proper shadows).
// Opaque textures -> OPAQUE; textures with see-through parts (grass, leaves, fences) -> MASK cut-out.
const opaqueCache = new Map();
let toOpaque = 0, toMask = 0;
for (const mat of root.listMaterials()) {
  if (mat.getAlphaMode() !== 'BLEND') continue;
  const tex = mat.getBaseColorTexture();
  let opaque = mat.getAlpha() >= 0.999;
  if (opaque && tex) {
    if (!opaqueCache.has(tex)) opaqueCache.set(tex, (await sharp(Buffer.from(tex.getImage())).stats()).isOpaque);
    opaque = opaqueCache.get(tex);
  }
  if (opaque) { mat.setAlphaMode('OPAQUE'); toOpaque++; }
  else { mat.setAlphaMode('MASK'); mat.setAlphaCutoff(0.5); toMask++; }
}
console.log('materials -> opaque', toOpaque, '| cut-out', toMask);

await io.write(out, doc);
console.log('nodes', root.listNodes().length, 'meshes', root.listMeshes().length,
  'materials', root.listMaterials().length, 'textures', root.listTextures().length);
