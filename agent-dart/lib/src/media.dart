// WebRTC for the SDK. CalloopAgent creates peer connections and gets the
// microphone through this, so tests can pass fakes; FlutterWebrtcMedia is the
// real one (flutter_webrtc).
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Every offer the SDK makes: audio only. Without it flutter_webrtc on Android
/// adds a receive-only video section, which a SIP carrier gets in the INVITE
/// (a 4 KB INVITE over UDP is refused with 413).
const Map<String, dynamic> audioOnlyOffer = {
  'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
  'optional': [],
};

abstract class CalloopMedia {
  Future<rtc.RTCPeerConnection> createPeerConnection(Map<String, dynamic> configuration);

  /// The microphone.
  Future<rtc.MediaStream> getMicrophone();
}

class FlutterWebrtcMedia implements CalloopMedia {
  const FlutterWebrtcMedia({this.audioConstraints = defaultAudio});

  static const Map<String, dynamic> defaultAudio = {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  };

  final Map<String, dynamic> audioConstraints;

  @override
  Future<rtc.RTCPeerConnection> createPeerConnection(Map<String, dynamic> configuration) =>
      rtc.createPeerConnection({'sdpSemantics': 'unified-plan', ...configuration});

  @override
  Future<rtc.MediaStream> getMicrophone() =>
      rtc.navigator.mediaDevices.getUserMedia({'audio': audioConstraints, 'video': false});
}
