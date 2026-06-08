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

## Roadmap

- macOS plugin build and packaging.
- Linux plugin build and packaging.
- Cross-platform install and uninstall flow for the packaged plugin.
- Keep the bridge protocol and source naming aligned across all supported platforms.

## Automation

- Pushes to `main` build the Windows plugin and upload the staged DLL as a GitHub Actions artifact.
- Pushes to `main` also publish a `dev-release` prerelease with the latest beta installer and DLL assets.
- Tag pushes that match `v*` build the plugin, package a Windows installer EXE, and publish the installer plus DLL as GitHub Release assets.

## Build

Run:

```powershell
npm run build:obs-plugin
```

To build the Windows installer EXE after the plugin DLL is staged, run:

```powershell
npm run build:installer
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

For end users, the GitHub release also publishes a Windows installer EXE that
shows a dialog with install and uninstall choices, copies the DLL into OBS, and
drops the uninstall script into the plugin data folder.

## Uninstall

Remove the installed plugin files from OBS and delete the `RelayAudio Audio Bridge`
source from your OBS scenes.


