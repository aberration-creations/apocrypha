A simple cross platform ui library. 

Everything gets rendered into a canvas in CPU memory. You then may do
as you wish with the canvas:
 - upload it as texture to GPU and overlay it on screen or inside 3d scene
 - output it on a window via a window manager
 - dump it to a file or output stream 

To use import public functions from [`src/index.zig`](src/index.zig)

To run examples see [`.vscode/tasks.json`](.vscode/tasks.json)

Required for x11 integration:

    libxcb1-dev
    libxcb-image0-dev

Some commands assume having [ffmpeg](https://ffmpeg.org/) in PATH