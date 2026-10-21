# calloop_agent

The agent side of Calloop's [agent protocol](https://docs.calloop.net/docs/agents/protocol) for
Flutter: connect, go available, ring, answer, hang up, transfer, keep calls
alive across network drops, app restarts and device switches, and — for
supervisors — the tenant's live calls and monitoring (listen / whisper /
barge). Same model and behaviour as the JS SDK ([`@calloop/agent-sdk`](https://docs.calloop.net/docs/sdks/js)).

The app keeps its own screens and ringtones; the SDK gives it state
(`ChangeNotifier`, works with Provider), events (streams) and the audio.

```sh
flutter pub add calloop_agent
```

```dart
import 'package:calloop_agent/calloop_agent.dart';

final agent = await CalloopAgent.connect(
  url: 'https://api.calloop.net',
  deviceId: storedDeviceId,                       // stable per installation
  getToken: () => api.fetchCalloopToken(),         // your backend signs it; called on every (re)connect
);

agent.setAvailability(Availability.available);

agent.onIncoming.listen((call) {
  showRinging(call.customer);                     // your UI
  // later: await call.accept();  or  call.decline();
});
agent.onCallEnded.listen((e) => closeCallScreen(e.call, e.end.reason));
```

## The agent

| | |
|---|---|
| `CalloopAgent.connect(url:, deviceId:, token: \| getToken:, purpose:?, media:?, transport:?)` | completes on `session:ready`. `purpose`: `'session'` (default) is the agent's main connection; anything else is auxiliary — no presence, no redelivered ringing calls, no resync on connect. `media` / `transport` replace the WebRTC and socket layers (e.g. fakes in tests) |
| `agent.ready` | a `Future` that completes with the agent once it is first identified |
| `agent.status` | `connecting` · `ready` · `reconnecting` · `closed` |
| `agent.closedReason` | set when Calloop ended the connection itself (status `closed` without `close()`: the token's signing key was revoked). It won't reconnect: `close()` the agent and connect again with a token signed by a current key |
| `agent.me`, `agent.isSupervisor`, `agent.availability` | |
| `agent.session`, `agent.iceServers` | the whole `session:ready`; the ICE servers Calloop gave this session |
| `agent.setAvailability(Availability.available \| offline, agentId:?)` | `onCall` is Calloop's |
| `agent.calls`, `agent.ringingCalls`, `agent.activeCall`, `agent.call(id)` | this agent's calls |
| `agent.queues`, `agent.team` | queue snapshots, agents' availability — only for supervisors and agents whose tenant allows the team view; otherwise no queues, and the team holds only this agent |
| `agent.sync()` | re-read the calls and queue snapshots now (done on every connect) |
| `agent.startOutbound(callId)` | a call your backend created (`POST /v1/tenants/{t}/calls`) |
| `agent.refreshSession()` | new ICE/TURN credentials (automatic before they expire) |
| `agent.close()` | |

Streams: `onIncoming`, `onElsewhere` (your call is on another device),
`onCallState`, `onCallEnded`, `onError`, `onBoardCallEnded`. `onError` is a
`Stream<Object>`: a `CalloopError` (`code`, `message`, `callId`) for Calloop's
`call:error`, or the socket's raw `connect_error` value (e.g. an authentication
refusal) — check the type.

## A call

`call.state`: `ringing` → `connecting` → `active` → `ended`; `dialing` for
outbound before the customer answers; `elsewhere` when its media is on another
of your devices.

| | |
|---|---|
| `call.accept()` / `call.decline()` / `call.hangup()` | |
| `call.mute(bool)`, `call.muted` | |
| `call.transfer(agentId:)` / `call.transfer(queueId:)` | |
| `call.setPrivate(bool)` | talk only to the monitoring supervisor |
| `call.switchHere()` | take a call that's active on another device |
| `call.customer`, `call.direction`, `call.callUuid`, `call.data` | |
| `call.isRingAll` | offered to every member of a `RING_ALL` queue at once (first accept wins) |
| `call.endReason` | the `CallEnd` once the call is over, else `null` |
| `call.remoteStream`, `call.localStream` | native platforms play the remote audio by themselves |
| `call.signals` | `DtmfSignal`, `CustomerMediaSignal`, `NetworkTerminatingSignal`, `SupervisorModeSignal`, `PrivateChangedSignal` |
| `call.ended` | `Future<CallEnd>` — `reason`: hangup, declined, withdrawn, answered_elsewhere, terminated (see `terminationReason`: the call ended — or, with `transferred`, this agent's part of it did, while the call goes on with the next agent), gone, accept_failed, media_failed, error. A failed call's `failure`: `{ code, title, details? }`, what the provider said (a SIP trunk: `404`, `Not Found`, its `Reason` header) |

## Supervisors

`agent.board` — the tenant's live calls (`CallData`: status, customer, agent,
queue, `ivr` position), kept current and rebuilt on every sync.

A dashboard on a large tenant narrows and pages instead (the agent protocol's
Board section): `agent.subscribeBoard(channelIds: […], queueIds: […], agentIds: […])`,
`agent.unsubscribeBoard()`, `agent.boardCalls(channelIds:, queueIds:, agentIds:, cursor:, limit:)` →
`(calls, nextCursor)`, `agent.boardCounters()` and the pushed
`agent.onCounters` stream.

`agent.board` and `onBoardCallEnded` are supervisors' only. An agent whose
tenant has the team view can page the board with `boardCalls()`, but the SDK
gives it no live board updates.

A filter lasts for one connection: after a reconnect Calloop subscribes the new
connection to the whole tenant again, so call `subscribeBoard()` again each
time `agent.status` returns to `ready`.

Supervisors also move any call with `agent.transferCall(callId, agentId: …)` or
`agent.transferCall(callId, queueId: …)`.

```dart
final monitor = await agent.monitor(callId);   // asks for the microphone
monitor.setMode(MonitorMode.whisper);           // listen | whisper | barge
monitor.mute(true);                             // your microphone
monitor.stop();
```

`agent.monitorOf(callId)` returns the call's monitor, if any.
`monitor.stream` (the call as the supervisor hears it), `monitor.mode`,
`monitor.state`, `monitor.muted`, `monitor.error`, `monitor.endReason` (once it
ended), `monitor.ended` — completes with the reason:
`stopped`, `call_ended`, `ended` (Calloop ended it), `disconnected`, `failed`
(Calloop couldn't start it; `monitor.error` says why), `not_allowed` (the tenant
doesn't allow monitoring), `closed` (`agent.close()`). A `setMode()` Calloop
refuses (whisper on a direct call, a mode the tenant doesn't allow) sets
`monitor.error` and monitoring goes on in the current mode. A reconnect ends
monitoring. Unlike the JS SDK, the monitor doesn't yet tell you when the agent
talks privately to you or when the agent's leg was rebuilt.

Direct calls (`call.data.isDirect`: a personal line's 1:1 call that Calloop
relays without a room) reconnect like any other call (the SDK sends its own
offer); monitoring one is
listen-only, without the microphone.

## The native call screen (`package:calloop_agent/native_calls.dart`)

The phone's own call UI: full-screen incoming call and ConnectionService on
Android, CallKit on iOS (via `flutter_callkit_incoming`). Import it only if you
want it; `calloop_agent.dart` doesn't use it.

```dart
import 'package:calloop_agent/native_calls.dart';

// In the app, once the agent is connected:
final native = CalloopNativeCalls(
  agent,
  style: const NativeCallStyle(appName: 'Acme Support'),
  ringPolicy: NativeRingPolicy.whenInBackground,   // or .always
  appInForeground: () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
);
await native.attach();
```

- A ringing call shows the native screen (keyed by Calloop's `callUuid`); when
  the call ends anywhere (answered elsewhere, withdrawn, hung up) the screen goes.
- Accept / Decline / End on the native screen act on the call: accept answers
  it, decline rejects it, end hangs up. Once answered the native call is marked
  connected.
- A tap that comes before the SDK knows the call (the app woke up from a push
  and is still connecting, or was launched by the Accept tap) is kept for
  `pendingFor` (45 s) and applied when the call arrives.

In the push handler (Android: FCM data messages, including the background
isolate):

```dart
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) async {
  await CalloopBackground.handlePush(message.data);   // null → not a Calloop call push
}
```

`handlePush` shows the screen for `call.incoming` and dismisses it for
`call.cancelled`. When the user declines while the app isn't running,
`CalloopBackground.declineCall(url:, deviceId:, getToken:, callId:)` connects,
sends the reject and disconnects, so the call moves on to the next agent right
away instead of waiting for the ring timeout. Its connection is auxiliary
(`purpose: 'decline'`): it doesn't count as the agent coming online, and
Calloop doesn't ring it with the call it is declining.

Android setup: `USE_FULL_SCREEN_INTENT`, `POST_NOTIFICATIONS` (asked at runtime
on Android 13+), `RECORD_AUDIO`, `FOREGROUND_SERVICE` /
`FOREGROUND_SERVICE_PHONE_CALL` / `FOREGROUND_SERVICE_MICROPHONE` in the
manifest; see the `flutter_callkit_incoming` docs. iOS (PushKit VoIP pushes and
CallKit) comes next.

## Security

- Put only short-lived **agent tokens** in the app, signed by your backend —
  never a Calloop API key. Calloop refuses agent tokens valid for more than
  24 hours (`exp` − now > 24 h), and treats a token without `role` as `AGENT`:
  a supervisor's token must say `role: SUPERVISOR`.
- Use `getToken` and fetch a fresh token there: it is called on every
  (re)connect.
- Keep tokens and any refresh credentials in `flutter_secure_storage`, not
  `SharedPreferences`.
- https / wss only. A release build refuses another gateway URL
  (`ArgumentError`), except `localhost`, `127.0.0.1`, `::1` and `10.0.2.2`; a
  debug build allows it with a warning.
- Use `flutter_callkit_incoming` >= 3.1.6: its receiver and activity are
  protected by a signature-level permission. Older or vendored copies (with
  `protectionLevel` normal) let other apps on the phone accept, decline or fake
  calls. `CalloopNativeCalls` also acts on Accept / Decline only for a call
  whose native screen this device showed, and ignores the rest.
- The call push's visible title is generic ("Incoming call"); the caller's
  name comes in the data fields (`customer_name`, `customer_address`) for the
  app's own UI.

## What it handles

- Resync on every connect: ringing calls ring, calls on this device reconnect
  after an app restart, calls on another device show as `elsewhere`.
- ICE candidates buffered both ways until each side is ready (including the
  ones Calloop sends while a call rings).
- Media recovery: no media within 15 s or a failed connection → one reconnect.
  If that fails too, the call ends locally with `media_failed` and the SDK asks
  Calloop to end it (`system_failed`), so Calloop records it `FAILED` /
  `NETWORK_ERROR`.
- One socket per agent (never shared with another connection to the same URL);
  a fresh token on every reconnect; TURN credentials from Calloop, refreshed.

## Testing

`flutter test` drives the SDK through the protocol with a scripted gateway and
fake WebRTC (`test/fakes.dart`), and the native layer with a fake call screen
(`test/native_test.dart`).
