# Nsis media server installer

## Build instructions

1. Clone [media server](https://github.com/dog4ik/media-server) in project root directory, build it. 
2. Clone [web client](https://github.com/dog4ik/media-server-web) in project root directory, build it. 
3. Get ffmpeg build in project root directory. ffmpeg/ffprobe binaries should be located in `ffmpeg/bin/`
4. Run the installer script `makensis.exe /DTMDB_TOKEN="<token>" media_server.nsi`.
