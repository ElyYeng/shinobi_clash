# Rasenshuriken test model setup

The Rasenshuriken projectile renderer looks for the model at:

`res://assets/rasenshuriken/scene.gltf`

The uploaded archive contains a folder named `rasenshuriken model1`. To use the authored model:

1. Extract `rasenshuriken model1.zip`.
2. In the Godot project, create `assets/rasenshuriken/`.
3. Copy the contents of the extracted `rasenshuriken model1/` folder into `assets/rasenshuriken/`.
4. Confirm that these paths exist:
   - `assets/rasenshuriken/scene.gltf`
   - `assets/rasenshuriken/scene.bin`
   - `assets/rasenshuriken/textures/`
5. Reopen Godot and let it import the glTF.

The glTF has no embedded animation clips. `Projectile` therefore animates it procedurally: the model is aligned to the projectile's travel direction and spun around its forward axis while it flies. If the GLTF has not been extracted, the ability uses a procedural spinning wind-shuriken fallback so the move remains usable.

The model itself is supplied by the project owner in the chat archive; the repository's GitHub text-file API cannot attach this binary archive automatically. Do not delete `scene.bin` or its textures when copying the model.
