// For code that runs without the app's CalloopAgent: the push handler
// (firebase_messaging's background isolate) and the native call screen's
// background callback (the user declined while the app wasn't running).
import 'dart:async';

import '../agent.dart';
import '../media.dart';
import '../transport.dart';
import 'native_ui.dart';
import 'push.dart';

class CalloopBackground {
  CalloopBackground._();

  /// Handle a push: a Calloop call push shows or dismisses the native call
  /// screen and returns the parsed push; anything else returns null untouched.
  static Future<CalloopPush?> handlePush(
    Map<dynamic, dynamic> data, {
    NativeCallUi? ui,
    NativeCallStyle style = const NativeCallStyle(),
  }) async {
    final push = CalloopPush.parse(data);
    if (push == null) return null;
    final native = ui ?? CallkitNativeUi();
    switch (push.type) {
      case CalloopPushType.incoming:
        await native.showIncoming(
          NativeIncoming(uuid: push.uuid, callId: push.callId, name: push.displayName, handle: push.customerAddress),
          style,
        );
      case CalloopPushType.cancelled:
        await native.end(push.uuid);
      case CalloopPushType.alert:
        break;   // iOS banner: the notification itself is the UI
    }
    return push;
  }

  /// Decline a call without the app's agent: connect, send call:reject, close.
  /// For a Decline tapped on the native screen while the app isn't running.
  /// The connection is auxiliary (purpose 'decline'): it takes no part in
  /// presence, and Calloop doesn't redeliver the ringing call to it.
  static Future<bool> declineCall({
    required String url,
    required String deviceId,
    required Object callId,
    String? token,
    TokenProvider? getToken,
    Duration timeout = const Duration(seconds: 10),
    CalloopTransport? transport,
  }) async {
    CalloopAgent? agent;
    try {
      // Not CalloopAgent.connect: on a timeout its agent would be lost, still connecting.
      agent = CalloopAgent(
        url: url, deviceId: deviceId, token: token, getToken: getToken, media: const _NoMedia(), transport: transport,
        purpose: 'decline',
      );
      await agent.ready.timeout(timeout);
      agent.send('call:reject', {'callId': callId});
      await Future<void>.delayed(const Duration(milliseconds: 500));   // let the emit leave before closing
      return true;
    } catch (_) {
      return false;
    } finally {
      agent?.close();
    }
  }
}

// A reject needs no audio.
class _NoMedia extends FlutterWebrtcMedia {
  const _NoMedia();
}
