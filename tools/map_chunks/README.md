# Big map -> streamed chunks

Turns one huge `.glb` map (e.g. a ripped level) into small chunks the game streams
around the player (`scripts/world/streamed_map.gd`). The output goes in `maps/_test_map/`,
which is in `.gitignore`: it stays on your PC and is never pushed or shipped.

## Run it (needs Node.js 18+)

```
cd tools/map_chunks
npm install
node --max-old-space-size=6000 clean.mjs  path/to/map.glb  clean.glb
node --max-old-space-size=6000 chunk.mjs  clean.glb  ../../maps/_test_map  150
```

Then open the project in Godot (it imports the chunks once - takes a few minutes) and play
the Main Game: when `maps/_test_map/chunks.json` exists, the main map is the streamed map
instead of Konoha. Delete the folder to get Konoha back.

## What the steps do

**clean.mjs** - drops the old sky dome / 12 km ground plane, removes duplicate textures,
materials and meshes, bakes every object into world space, caps textures (2048 px ground,
1024 px the rest), fixes rip problems (1x1 white grass texture -> grass green, alpha-0
materials -> visible) and turns Blender's BLEND materials into OPAQUE / alpha cut-out.

**chunk.mjs** - cuts the map into a grid (last argument = tile size in metres), merges
everything sharing a material inside each tile (thousands of draw calls -> a few per tile),
writes `c_<x>_<z>.gltf` + `.bin` per tile, `backdrop.gltf` (far mountains, always loaded),
the shared textures once in `tex/`, and `chunks.json` (the index the game reads).

## Spawn point

`chunks.json` -> `"spawn": [x, y, z]` is where you start (ground height). Edit it by hand.
