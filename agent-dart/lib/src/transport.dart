// The socket to Calloop's agent gateway. CalloopAgent talks to this interface,
// so tests can script the gateway; SocketIoTransport is the real one.
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef TransportHandler = void Function(dynamic payload);

// Hosts a release build may still reach without TLS: the device itself and the
// Android emulator's alias for the development machine.
const _localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
bool _warnedInsecure = false;

/// Checks a gateway URL: it must be https or wss — the agent's token and the
/// call signalling travel over it. A release build refuses anything else
/// (ArgumentError), local hosts excepted; a debug build allows it with a
/// warning, once. Returns whether the URL is insecure.
bool checkGatewayUrl(String url, {bool release = kReleaseMode}) {
  final uri = Uri.tryParse(url);
  final scheme = uri?.scheme.toLowerCase() ?? '';
  if (scheme == 'https' || scheme == 'wss') return false;
  if (_localHosts.contains(uri?.host.toLowerCase())) return true;
  if (release) {
    throw ArgumentError.value(url, 'url', 'Calloop gateway URL must be https:// or wss:// in a release build');
  }
  if (!_warnedInsecure) {
    _warnedInsecure = true;
    debugPrint('calloop_agent: insecure gateway URL "$url" — use https:// or wss:// (release builds refuse it)');
  }
  return true;
}

abstract class CalloopTransport {
  /// Connects; `auth` is called on every (re)connect for the handshake payload.
  void connect(Future<Map<String, dynamic>> Function() auth);
  void emit(String event, [Object? payload]);
  void on(String event, TransportHandler handler);

  /// 'connect', 'disconnect', 'connect_error' arrive through [on] as well.
  bool get connected;
  void close();
}

class SocketIoTransport implements CalloopTransport {
  SocketIoTransport(this.url) {
    checkGatewayUrl(url);
  }

  final String url;
  io.Socket? _socket;
  final Map<String, List<TransportHandler>> _handlers = {};

  @override
  void connect(Future<Map<String, dynamic>> Function() auth) {
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // One agent, one connection: never share a manager with another socket to the same URL.
          .enableForceNew()
          .setAuthFn((callback) {
            auth().then(callback, onError: (_) => callback(<String, dynamic>{}));
          })
          .build(),
    );
    _socket = socket;
    _handlers.forEach((event, handlers) {
      for (final h in handlers) {
        socket.on(event, h);
      }
    });
    socket.connect();
  }

  @override
  void emit(String event, [Object? payload]) => _socket?.emit(event, payload);

  @override
  void on(String event, TransportHandler handler) {
    (_handlers[event] ??= []).add(handler);
    _socket?.on(event, handler);
  }

  @override
  bool get connected => _socket?.connected ?? false;

  @override
  void close() {
    _socket?.dispose();
    _socket = null;
  }
}
