/// The platform's call screen for Calloop calls — CallKit on iOS, the
/// full-screen incoming-call UI and ConnectionService on Android
/// (flutter_callkit_incoming) — and Calloop's call pushes.
///
///   * CalloopNativeCalls(agent).attach()     in the app: mirror calls ↔ native screen
///   * CalloopBackground.handlePush(data)     in the push handler: show / dismiss
///   * CalloopBackground.declineCall(...)     a Decline tapped while the app isn't running
library;

export 'src/native/background.dart' show CalloopBackground;
export 'src/native/native_calls.dart' show CalloopNativeCalls, NativeRingPolicy;
export 'src/native/native_ui.dart' show NativeCallUi, CallkitNativeUi, NativeAction, NativeActionType, NativeCallStyle, NativeIncoming;
export 'src/native/push.dart' show CalloopPush, CalloopPushType, uuidForCall;
