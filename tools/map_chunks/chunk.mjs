// Step 2: cut the cleaned map into a grid of chunks the game streams around the player.
//   backdrop.glb        - the far mountains / outer scenery: big, always loaded
//   c_<x>_<z>.glb       - one per CELL x CELL metre tile (only tiles that have something in them)
//   chunks.json         - index: cell size, every chunk's file, bounds, triangle count
// Inside each file, everything that shares a material is merged into one mesh (join), which
// turns thousands of draw calls into a handful per chunk.
import { NodeIO, Document } from '@gltf-transform/core';
import { ALL_EXTENSIONS, KHRMaterialsSpecular } from '@gltf-transform/extensions';
import { copyToDocument, join, prune, dedup, weld, getBounds, unpartition } from '@gltf-transform/functions';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { plantMaterials } from './foliage.mjs';
import path from 'node:path';

const [src, outDir, cellArg] = process.argv.slice(2);
const CELL = Number(cellArg || 150);
const BACKDROP_EXTENT = 600;   // anything wider than this is scenery, not a walkable piece
fs.mkdirSync(outDir, { recursive: true });

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(src);
// the toon shading ignores the old game's specular maps (mostly flat single colours): drop them
for (const ext of doc.getRoot().listExtensionsUsed()) {
  if (ext.extensionName === KHRMaterialsSpecular.EXTENSION_NAME) ext.dispose();
}
await doc.transform(prune({ keepSolidTextures: true }));

const groups = new Map();   // key -> nodes
const add = (k, n) => { if (!groups.has(k)) groups.set(k, []); groups.get(k).push(n); };
const scene = doc.getRoot().listScenes()[0];
for (const node of scene.listChildren()) {
  if (!node.getMesh()) continue;
  const b = getBounds(node);
  const ext = Math.max(b.max[0] - b.min[0], b.max[2] - b.min[2]);
  if (ext > BACKDROP_EXTENT || /zback/i.test(node.getName())) { add('backdrop', node); continue; }
  const cx = Math.floor((b.min[0] + b.max[0]) / 2 / CELL);
  const cz = Math.floor((b.min[2] + b.max[2]) / 2 / CELL);
  add(`c_${cx}_${cz}`, node);
}

const index = { cell: CELL, spawn: [0, 0, 0], chunks: [], no_collision: plantMaterials(doc.getRoot()) };
try {   // keep a spawn point set by hand in an earlier chunks.json
  const old = JSON.parse(fs.readFileSync(path.join(outDir, 'chunks.json'), 'utf8'));
  for (const k of ['spawn', 'npcs', 'uchiha_gate', 'streets']) if (old[k] !== undefined) index[k] = old[k];   // hand-placed things survive a rebuild
} catch {}
let i = 0;
for (const [key, nodes] of groups) {
  i++;
  const out = new Document();
  const outScene = out.createScene(key);
  const map = copyToDocument(out, doc, nodes);
  for (const n of nodes) outScene.addChild(map.get(n));
  await out.transform(dedup(), join({ keepNamed: false }), weld(), unpartition(), prune({ keepSolidTextures: true }));
  // textures live once in tex/ (named by content hash) and every chunk points at them
  for (const t of out.getRoot().listTextures()) {
    const img = t.getImage();
    const ext = t.getMimeType() === 'image/jpeg' ? 'jpg' : 'png';
    t.setURI(`tex/${crypto.createHash('md5').update(img).digest('hex').slice(0, 16)}.${ext}`);
  }
  out.getRoot().listBuffers()[0].setURI(`${key}.bin`);
  const file = `${key}.gltf`;
  await io.write(path.join(outDir, file), out);
  const b = getBounds(outScene);
  let tris = 0;
  for (const m of out.getRoot().listMeshes()) for (const p of m.listPrimitives()) {
    const ix = p.getIndices();
    tris += ix ? ix.getCount() / 3 : p.getAttribute('POSITION').getCount() / 3;
  }
  const entry = { file, min: b.min.map((v) => +v.toFixed(2)), max: b.max.map((v) => +v.toFixed(2)),
    tris, meshes: out.getRoot().listMeshes().length, bytes: fs.statSync(path.join(outDir, `${key}.bin`)).size };
  if (key === 'backdrop') index.backdrop = entry; else {
    const [, x, z] = key.split('_').map(Number);
    entry.cell = [x, z];
    index.chunks.push(entry);
  }
  if (i % 10 === 0) console.log(`${i}/${groups.size} written`);
}
fs.writeFileSync(path.join(outDir, 'chunks.json'), JSON.stringify(index, null, 1));
const total = index.chunks.reduce((s, c) => s + c.bytes, 0);
console.log('chunks', index.chunks.length, 'total MB', (total / 1e6).toFixed(0),
  'largest MB', (Math.max(...index.chunks.map((c) => c.bytes)) / 1e6).toFixed(1),
  'backdrop MB', ((index.backdrop?.bytes || 0) / 1e6).toFixed(1));
