# OBS RelayAudio

OBS RelayAudio is the standalone OBS audio bridge project for BrowserRelayStreamer.

It builds the `RelayAudio Audio Bridge` OBS source plugin, which
connects to the app's localhost PCM bridge at `127.0.0.1:<port>` and forwards
audio into OBS.

## Current scope

- Windows-only OBS plugin build and packaging.
- OBS source registration for `RelayAudio Audio Bridge`.
- Localhost PCM bridge protocol with a configurable port.
- Build-time staging of the plugin DLL for packaging into the app.

## Build

Run:

```powershell
npm run build:obs-plugin
```

The build script downloads the OBS Studio source archive, generates the
required OBS headers and import library, and builds the plugin against the
local OBS runtime. The downloaded archive and generated import library are
cached under `build/cache/obs-plugin/`, so repeat builds avoid re-downloading
and re-parsing OBS exports unless OBS itself changes.

## Install

The plugin is staged under:

```text
dist/obs-plugin/browser-relay-audio/
```

Copy the staged DLL into the OBS installation or let the BrowserRelayStreamer
app package and install it from its bundled resources. The source property
defaults to `127.0.0.1:<port>`, but the port can be changed to match the app
setting.

## Uninstall

Remove the installed plugin files from OBS and delete the `RelayAudio Audio Bridge`
source from your OBS scenes.


