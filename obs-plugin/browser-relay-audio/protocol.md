# RelayAudio Protocol

Transport: TCP on `127.0.0.1:<port>`.

Default port: `47631`.

The port is configurable in the BrowserRelayStreamer settings screen and in the
OBS RelayAudio source properties. Both sides must use the same port.

Handshake from plugin to app:

```text
RELAYAUDIO HELLO 1
```

Audio packets are little-endian binary frames:

```c
struct BrsAudioPacketHeader {
  char magic[4];          // "BRSA"
  uint16_t version;       // 1
  uint16_t headerBytes;   // sizeof(BrsAudioPacketHeader)
  uint32_t sampleRate;    // normally 48000
  uint16_t channels;      // normally 2
  uint16_t format;        // 1 = interleaved float32 little endian
  uint32_t frames;
  uint64_t timestampNs;
  uint32_t payloadBytes;
};
```

Payload follows immediately after the header. For format `1`, payload is
interleaved float32 PCM with `frames * channels` samples.
