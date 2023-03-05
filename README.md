# Godot 4 3D Pixelart Shader Demo

This demo shows a basic setup for using the 3D pixel art outline/highlight shaders I made. 

Note that the shaders only work as intended when using a **low game resolution**. If you want to have a higher resolution UI you should render the "game" part inside a sub-viewport and apply the texture to a sprite. If you want to pixelize a high-resolution render you'll have to use something else, though this shader could be combined with a pixelization shader. 

![alt text](https://i.imgur.com/2h5ovsW.png)
Before and after. Shader in screenshot is a previous iteration, current one is cleaner.

Inspired by [this shader Kody King](https://threejs.org/examples/webgl_postprocessing_pixel.html).

**There are two shaders:**
1. Post-processing shader that affects everything on the screen
2. Object-specific shader. This is best used as second pass on top of a base material - see demo

## Notes

- Orthographic camera has some quirks that are non-specific to the shader:
    - SDFGI & VocelGI not supported [(Github issue)](https://github.com/godotengine/godot/issues/70944)
    - DirectionalLight3D shadows behave weird. To fix configure either your Camera's `Far` property or your DirectionalLight3D's `Split 1` property.
- Special thanks to [oJadeo](https://github.com/oJadeo) for informing me about Godot 4's normal buffer :)

## License

MIT, you can use & modify it however you like. 


If you use the effect in a game I'd love to see it!
