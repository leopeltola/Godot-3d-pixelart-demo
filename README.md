# Godot 4 3D Pixelart Shader Demo

This demo shows a basic setup for using the 3D pixel art outline/highlight shaders I made. 

Note that the shaders only work as intended when using a **low game resolution**. If you want to have a higher resolution UI you should render the "game" part inside a sub-viewport and apply the texture to a sprite. If you want to pixelize a high-resolution render you'll have to use something else, though this shader could be combined with a pixelization shader. 

**There are two shaders:**
1. Post-processing shader that affects everything on the screen
2. Object-specific shader. This is best used as second pass on top of a base material - see demo

## Bugs

The shaders are nowhere near perfect. Most problems stem from calculating the normals.

I might try fixing these later if they annoy me enough. If you know/figure out a fix feel free to send it to me, open a pull request or fork the repo so that others can use it too.

### Post-processing shader

- Highlights aren't clean
- Highlights sometimes leak outside objects

### Object shader

- Highlights aren't clean

## Notes

- Orthographic camera has some caveats that are non-specific to the shader:
    - SDFGI not supported, [Github issue](https://github.com/godotengine/godot/issues/70944)
    - DirectionalLight3D shadows behave weird. To fix configure either your Camera's `far` property or your DirectionalLight3D's `Split 1` property.

## License

MIT, you can use & modify it however you like. 

If you use the effect in a game I'd love to see it!