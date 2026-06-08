# RelayAudio OBS Audio Bridge

This OBS plugin replaces the Windows virtual audio driver plan.

The app starts a localhost bridge on a configurable port. The OBS plugin
registers an audio input source named `RelayAudio Audio Bridge`, connects to the
bridge, and forwards PCM frames into OBS through libobs.

Current status:

- Driver install path is no longer the primary design.
- The app-side bridge server and OBS connection state exist.
- The plugin source skeleton registers an OBS source and contains the TCP/PCM
  receive loop.
- Browser audio capture and packet emission from Electron still need to be
  attached to the app-side bridge.

Roadmap:

- macOS support for the plugin build and install flow.
- Linux support for the plugin build and install flow.
- Shared protocol behavior across Windows, macOS, and Linux builds.

## Build

The build flow downloads the OBS Studio source archive, generates the minimal
headers and import library needed for local linking, and builds this plugin
against the OBS install that is already on the machine.

Run:

```powershell
npm run build:obs-plugin
```

The build script stages the plugin into `dist/obs-plugin/browser-relay-audio/`,
which is the location the app looks for when it is packaged or run from a local
build tree.

## Uninstall

Remove the installed files from OBS with:

```powershell
.\obs-plugin\browser-relay-audio\uninstall.ps1
```

After that, remove the `RelayAudio Audio Bridge` source from OBS scenes.


