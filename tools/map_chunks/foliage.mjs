// Which materials are plants (no collision): most of their triangles belong to objects whose names
// say grass / bush / foliage / leaves (Japanese names in the rip: kusa = grass, ha = leaf, eda = branch,
// ki = tree). For tree names only the see-through (alpha cut) materials count, so trunks stay solid.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
export const PLANT = /(kusa|grass|bush|foliage|leaf|leaves|plant|backgroundtrees|crowd|(^|_)eda\d*|(^|_)ha\d{3})/i;
export const TREE = /((^|_)ki\d{3}|tree)/i;
export function plantMaterials(root) {
  const stat = new Map();
  for (const node of root.listNodes()) {
    const mesh = node.getMesh(); if (!mesh) continue;
    const name = node.getName();
    for (const p of mesh.listPrimitives()) {
      const mat = p.getMaterial(); if (!mat) continue;
      const tris = (p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount()) / 3;
      const s = stat.get(mat) ?? { plant: 0, all: 0 };
      s.all += tris;
      if (PLANT.test(name) || (TREE.test(name) && mat.getAlphaMode() !== 'OPAQUE')) s.plant += tris;
      stat.set(mat, s);
    }
  }
  return [...stat].filter(([, s]) => s.plant / s.all > 0.6).map(([m]) => m.getName());
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href && process.argv[2]) {   // run directly (not imported)
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
  const doc = await io.read(process.argv[2]);
  const list = plantMaterials(doc.getRoot());
  for (const f of process.argv.slice(3)) {
    const d = JSON.parse(fs.readFileSync(f, 'utf8'));
    d.no_collision = list;
    fs.writeFileSync(f, JSON.stringify(d, null, 1));
  }
  console.log('plant materials', list.length);
  console.log(list.join(' | '));
}
