# Godot 4 3D Pixelart Shader Demo

This demo shows a basic setup for using the 3D pixel art outline/highlight shaders I made. 

Note that the shaders only work as intended when using a **low game resolution**. If you want to have a higher resolution UI you should render the "game" part inside a sub-viewport and apply the texture to a sprite. If you want to pixelize a high-resolution render you'll have to use something else, though this shader could be combined with a pixelization shader. The shader is meant for the **Forward+** renderer. 

![alt text](https://i.imgur.com/2h5ovsW.png)
Before and after. Shader in screenshot is a previous iteration, current one is cleaner.

Inspired by [this shader Kody King](https://threejs.org/examples/webgl_postprocessing_pixel.html).

**The shader can be used as both a post-processing and object shader.** It may cause [bugs with transparency](https://github.com/leopeltola/Godot-3d-pixelart-demo/issues/4), I recommend using it on specific objects for finer control.

## Notes

- Orthographic camera has some quirks that are non-specific to the shader:
    - SDFGI & VocelGI not supported [(Github issue)](https://github.com/godotengine/godot/issues/70944)
    - DirectionalLight3D shadows behave weird. To fix configure either your Camera's `Far` property or your DirectionalLight3D's `Split 1` property.
- Special thanks to [oJadeo](https://github.com/oJadeo) for informing me about Godot 4's normal buffer :)

## License

MIT, you can use & modify it however you like. 


If you use the effect in a game I'd love to see it!
