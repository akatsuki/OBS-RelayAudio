#include <obs-module.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#endif

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("browser-relay-audio", "en-US")

namespace {

constexpr const char *kSourceId = "browser_relay_audio_bridge";
constexpr const char *kSourceName = "RelayAudio Audio Bridge";
constexpr const char *kDefaultHost = "127.0.0.1";
constexpr int kDefaultPort = 47631;
constexpr uint16_t kProtocolVersion = 1;
constexpr uint16_t kFormatFloat32Interleaved = 1;

#pragma pack(push, 1)
struct BrsAudioPacketHeader {
  char magic[4];
  uint16_t version;
  uint16_t headerBytes;
  uint32_t sampleRate;
  uint16_t channels;
  uint16_t format;
  uint32_t frames;
  uint64_t timestampNs;
  uint32_t payloadBytes;
};
#pragma pack(pop)

struct BridgeSource {
  obs_source_t *source = nullptr;
  std::string host = kDefaultHost;
  int port = kDefaultPort;
  std::mutex configMutex;
  std::atomic<bool> running{true};
#ifdef _WIN32
  std::atomic<SOCKET> activeSocket{INVALID_SOCKET};
#endif
  std::thread worker;
};

obs_source_info bridge_source_info = {};

const char *bridge_get_name(void *) {
  return kSourceName;
}

bool recv_exact(SOCKET socket, void *buffer, int bytes) {
  auto *cursor = static_cast<char *>(buffer);
  int remaining = bytes;

  while (remaining > 0) {
    const int read = recv(socket, cursor, remaining, 0);
    if (read <= 0) {
      return false;
    }

    cursor += read;
    remaining -= read;
  }

  return true;
}

void output_packet(BridgeSource *context, const BrsAudioPacketHeader &header,
                   const std::vector<uint8_t> &payload) {
  if (std::memcmp(header.magic, "BRSA", 4) != 0 ||
      header.version != kProtocolVersion ||
      header.headerBytes != sizeof(BrsAudioPacketHeader) ||
      header.format != kFormatFloat32Interleaved || header.channels == 0 ||
      header.frames == 0 || payload.empty()) {
    return;
  }

  obs_source_audio audio = {};
  audio.data[0] = payload.data();
  audio.frames = header.frames;
  audio.speakers = header.channels == 1 ? SPEAKERS_MONO : SPEAKERS_STEREO;
  audio.samples_per_sec = header.sampleRate;
  audio.format = AUDIO_FORMAT_FLOAT;
  audio.timestamp = header.timestampNs;

  obs_source_output_audio(context->source, &audio);
}

void bridge_loop(BridgeSource *context) {
#ifdef _WIN32
  WSADATA wsa = {};
  if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
    blog(LOG_WARNING, "[BRS audio] WSAStartup failed");
    return;
  }

  while (context->running.load()) {
    std::string host;
    int port = 0;
    {
      std::lock_guard<std::mutex> lock(context->configMutex);
      host = context->host;
      port = context->port;
    }

    SOCKET socket = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (socket == INVALID_SOCKET) {
      break;
    }

    sockaddr_in address = {};
    address.sin_family = AF_INET;
    address.sin_port = htons(static_cast<uint16_t>(port));
    inet_pton(AF_INET, host.c_str(), &address.sin_addr);

    if (connect(socket, reinterpret_cast<sockaddr *>(&address),
                sizeof(address)) == SOCKET_ERROR) {
      closesocket(socket);
      std::this_thread::sleep_for(std::chrono::milliseconds(600));
      continue;
    }

    context->activeSocket.store(socket);
    const char hello[] = "RELAYAUDIO HELLO 1\n";
    send(socket, hello, static_cast<int>(std::strlen(hello)), 0);

    std::vector<uint8_t> payload;
    while (context->running.load()) {
      BrsAudioPacketHeader header = {};
      if (!recv_exact(socket, &header, sizeof(header)) ||
          header.payloadBytes > 1024 * 1024) {
        break;
      }

      payload.resize(header.payloadBytes);
      if (!recv_exact(socket, payload.data(),
                      static_cast<int>(payload.size()))) {
        break;
      }

      output_packet(context, header, payload);
    }

    closesocket(socket);
    context->activeSocket.store(INVALID_SOCKET);
  }

  WSACleanup();
#else
  blog(LOG_WARNING, "[BRS audio] non-Windows socket implementation pending");
#endif
}

void *bridge_create(obs_data_t *settings, obs_source_t *source) {
  auto *context = new BridgeSource();
  context->source = source;
  {
    std::lock_guard<std::mutex> lock(context->configMutex);
    context->host = obs_data_get_string(settings, "host");
    context->port = static_cast<int>(obs_data_get_int(settings, "port"));
  }
  context->worker = std::thread(bridge_loop, context);
  return context;
}

void bridge_update(void *data, obs_data_t *settings) {
  auto *context = static_cast<BridgeSource *>(data);
  {
    std::lock_guard<std::mutex> lock(context->configMutex);
    context->host = obs_data_get_string(settings, "host");
    context->port = static_cast<int>(obs_data_get_int(settings, "port"));
  }

#ifdef _WIN32
  const SOCKET socket = context->activeSocket.exchange(INVALID_SOCKET);
  if (socket != INVALID_SOCKET) {
    shutdown(socket, SD_BOTH);
    closesocket(socket);
  }
#endif
}

void bridge_destroy(void *data) {
  auto *context = static_cast<BridgeSource *>(data);
  context->running.store(false);

#ifdef _WIN32
  const SOCKET socket = context->activeSocket.exchange(INVALID_SOCKET);
  if (socket != INVALID_SOCKET) {
    shutdown(socket, SD_BOTH);
    closesocket(socket);
  }
#endif

  if (context->worker.joinable()) {
    context->worker.join();
  }

  delete context;
}

void bridge_defaults(obs_data_t *settings) {
  obs_data_set_default_string(settings, "host", kDefaultHost);
  obs_data_set_default_int(settings, "port", kDefaultPort);
}

bool bridge_reset_defaults(obs_properties_t *, obs_property_t *, void *data) {
  auto *context = static_cast<BridgeSource *>(data);
  obs_data_t *settings = obs_data_create();
  obs_data_set_string(settings, "host", kDefaultHost);
  obs_data_set_int(settings, "port", kDefaultPort);
  obs_source_reset_settings(context->source, settings);
  obs_data_release(settings);
  return false;
}

obs_properties_t *bridge_properties(void *data) {
  obs_properties_t *props = obs_properties_create();
  obs_properties_add_text(props, "host", "Host", OBS_TEXT_DEFAULT);
  obs_properties_add_int(props, "port", "Port", 1, 65535, 1);
  obs_properties_add_button2(props, "reset_defaults", "デフォルトに戻す",
                             bridge_reset_defaults, data);
  return props;
}

} // namespace

bool obs_module_load(void) {
  bridge_source_info.id = kSourceId;
  bridge_source_info.type = OBS_SOURCE_TYPE_INPUT;
  bridge_source_info.output_flags = OBS_SOURCE_AUDIO;
  bridge_source_info.get_name = bridge_get_name;
  bridge_source_info.create = bridge_create;
  bridge_source_info.update = bridge_update;
  bridge_source_info.destroy = bridge_destroy;
  bridge_source_info.get_defaults = bridge_defaults;
  bridge_source_info.get_properties = bridge_properties;

  obs_register_source(&bridge_source_info);
  blog(LOG_INFO, "[BRS audio] loaded");
  return true;
}
