A simple cross platform gui library.

![Screenshot of 2048 game made using this library](./docs/screenshot-2048.png)
![Screenshot of a path tracer](./docs/screenshot-pathtracer.png)

Everything gets rendered into a canvas in CPU memory. You then may do
as you wish with the canvas:
 - upload it as texture to GPU and overlay it on screen or inside 3d scene
 - output it on a window via a window manager
 - dump it to a file or output stream 

To use import public functions from [`src/index.zig`](src/index.zig)

Examples can be found at top level.
 - to run on windows `zig run 2048.zig`
 - to run on linux `zig run 2048.zig -lc -lxcb -lxcb-image`

Examples can be run with [`.vscode/tasks.json`](.vscode/tasks.json)

On linux the following need to be installed for the x11 integration to work:

    sudo apt install libxcb1-dev libxcb-image0-dev
