/// Calloop agent SDK for Flutter: the agent side of Calloop's agent protocol
/// (docs/agent-protocol.md) — calls, availability, devices, supervisor board
/// and monitoring — over Socket.IO and WebRTC (flutter_webrtc).
library;

export 'src/agent.dart' show CalloopAgent, CallEnded, CallStateChange, BoardCallEnded, TokenProvider;
export 'src/call.dart' show CalloopCall;
export 'src/media.dart' show CalloopMedia, FlutterWebrtcMedia;
export 'src/models.dart';
export 'src/monitor.dart' show CalloopMonitor;
export 'src/transport.dart' show CalloopTransport, SocketIoTransport, TransportHandler;
