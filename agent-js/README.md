# @calloop/agent-sdk

The agent side of Calloop's [agent protocol](https://docs.calloop.net/agents/protocol) for
browsers and Node: connect, go available, ring, answer, hang up, transfer,
and keep calls alive across network drops, page reloads and device switches.
The app keeps its own UI, ringtones and routing; the SDK gives it events,
state and the remote audio stream.

```sh
npm install @calloop/agent-sdk
```

```js
import { connect } from '@calloop/agent-sdk';

const agent = await connect({
  url: 'https://api.calloop.net',
  getToken: () => fetch('/api/calloop-token').then((r) => r.text()), // your backend signs it
});

agent.setAvailability('AVAILABLE');

agent.on('incoming', (call) => {
  ring(call.customer);                       // your UI
  call.on('remoteStream', (stream) => { audioEl.srcObject = stream; });
  call.on('ended', ({ reason }) => stopRinging());
  acceptButton.onclick = () => call.accept();  // asks for the microphone
  declineButton.onclick = () => call.decline();
});
```

## Connecting

`connect(options)` resolves once Calloop has identified the agent (`session:ready`).

| Option | |
|---|---|
| `url` | Calloop's base URL |
| `getToken` | `async () => jwt`, called on every (re)connect — agent tokens are short-lived. Or `token` for a fixed one. |
| `deviceId` | Stable id for this device (default: one kept in `localStorage`). Calloop uses it to tell "this device" from "my other device". |
| `webrtc` | `{ RTCPeerConnection, MediaStream }` outside a browser (e.g. `@roamhq/wrtc` in Node) |
| `getUserMedia` | `async () => MediaStream` for the microphone (default: `navigator.mediaDevices.getUserMedia`) |
| `io` | socket.io-client's `io` (default: the bundled one) — to use the app's own socket.io-client |
| `purpose` | `'session'` (default): the agent's main connection. Anything else (e.g. `'decline'`) is an auxiliary connection: no presence, no redelivered ringing calls, no resync on connect |

ICE/TURN servers come from Calloop; the app never configures them.

The SDK reconnects by itself after a network drop (`disconnected`, then
`ready`). When Calloop itself ends the connection — the token's signing key was
revoked — socket.io doesn't retry: the agent emits `closed` ({ reason }) and
sets `agent.closedReason`. Call `agent.close()` and `connect()` again with a
token signed by a current key. The same happens when the agent's role changes,
the agent is deleted, or its tenant or consumer is suspended.

## Security

- **Only agent tokens in the client.** The browser or app gets a short-lived
  agent token from your backend (5–15 minutes; Calloop refuses one valid for
  more than 24 hours). Never put a Calloop API key or a signing key in client
  code: they're your backend's alone.
- **A fresh token per connect.** Give `getToken`, not a fixed `token`: it runs
  on every (re)connect. Keep the token in memory, not `localStorage`.
- **`role` on every token.** A token without `role` connects as `AGENT`; send
  `role: 'SUPERVISOR'` on a supervisor's tokens every time.
- **https only.** `url` is `https://…` outside local development (the SDK warns
  in the console otherwise): the token and the call's signalling travel over it.
- **What ends a session.** Calloop disconnects an agent's sockets when its
  signing key is revoked, its role changes, it's deleted, or its tenant or
  consumer is suspended (`closed`, below). Reconnect with a fresh token, or not
  at all.

## The agent

| | |
|---|---|
| `agent.setAvailability('AVAILABLE' \| 'OFFLINE', { agentId? })` | `ON_CALL` is set by Calloop; `agentId`: a supervisor setting someone else |
| `agent.startOutbound(callId, { stream? })` | start an outbound call the consumer created (`POST /v1/tenants/{t}/calls`) |
| `agent.calls`, `agent.call(id)` | this agent's calls |
| `agent.availability` | this agent's availability (`AVAILABLE` · `ON_CALL` · `OFFLINE`), as Calloop reports it |
| `agent.queues` | queue snapshots by queue id (see below) |
| `agent.team` | the tenant's agents' availability, as it changes (see below) |
| `agent.sync()` | re-read the calls and queue snapshots now (done on every connect) |
| `agent.refreshSession()` | new ICE/TURN credentials (done automatically before they expire) |
| `agent.ready` | a promise that resolves with the agent once it is first identified |
| `agent.agent`, `agent.session` | identity from `session:ready` |
| `agent.iceServers`, `agent.deviceId` | the ICE servers Calloop gave this session; this device's id |
| `agent.close()` | |

Queue snapshots and the team's availability come only to supervisors and to
agents whose tenant allows the team view (the tenant's `team_view` setting).
Without it, a plain agent gets no queues, and `agent.team` holds only itself.

`on(event, fn)` returns a function that removes the listener; `once()` and
`off()` work as usual, on the agent, a call and a monitor.

Events: `incoming` (call), `elsewhere` (call), `callState` (call, state, previous),
`callEnded` (call, info), `availability`, `team`, `queue`, `ready` (after each reconnect),
`sessionRefreshed`, `disconnected`, `closed` ({ reason }: Calloop ended the
connection, see above), `error`.

## A call

`call.state`: `ringing` → `connecting` → `active` → `ended`; `dialing` for an
outbound call before the customer answers; `elsewhere` when its media is on
another of the agent's devices.

| | |
|---|---|
| `call.accept({ stream? })` | answer (default microphone) |
| `call.decline()` | in a queue, it passes to the next agent |
| `call.hangup()` | |
| `call.mute(bool)` | |
| `call.transfer({ agentId } \| { queueId })` | |
| `call.switchHere({ stream? })` | take a call that's active on another device |
| `call.setPrivate(bool)` | talk privately to the monitoring supervisor |
| `call.customer`, `call.direction`, `call.channel`, `call.callUuid`, `call.queueId`, `call.data` | |
| `call.isRingAll` | offered to every member of a `RING_ALL` queue at once (first accept wins) |
| `call.muted`, `call.endReason` | as set by `mute()`; why the call ended (`null` until then) |
| `call.remoteStream`, `call.localStream`, `call.pc` | |

Events: `state` (state, previous), `remoteStream` (stream), `ended` ({ reason }),
`updated`, `dtmf`, `customerMedia`, `networkTerminating`, `supervisorMode`,
`privateChanged`.

`ended` reasons: `hangup`, `declined`, `terminated` (see
`terminationReason`: the call ended — or, with `transferred`, this agent's part
of it did: the previous agent of a transfer gets it while the call goes on with
the next one), `withdrawn` (the offer went to someone else),
`answered_elsewhere`, `media_failed`, `accept_failed`, `error`, `gone`.
A failed call's `terminated` also carries `failure`: `{ code, title, details? }`,
what the provider said (a SIP trunk: `404`, `Not Found`, its `Reason` header).
Other details by reason:

| `reason` | Also in the `ended` info |
|---|---|
| `terminated` | `terminationReason`, `terminatedBy`, `failure` |
| `withdrawn` | `withdrawnReason`: `declined` · `taken` · `timeout` · `overflow` |
| `answered_elsewhere` | `by` (the agent id), `agentName` |
| `error` | `code`, `message` |
| `media_failed`, `accept_failed` | `error` (the message), when there is one |

## Supervisors

An agent whose token has `role: 'SUPERVISOR'` (`agent.isSupervisor`) also gets:

| | |
|---|---|
| `agent.board` | the tenant's live calls (`Map` callId → call view: status, direction, customer, agent, queue, `ivr` position), rebuilt on every sync. `ivr` is filled by live IVR events only: after a sync it is missing until the call's next IVR step |
| `agent.monitor(callId, { stream? })` | listen to a call → a `Monitor` |
| `agent.monitors` | the calls being monitored (`Map` callId → `Monitor`) |
| `agent.transferCall(callId, { agentId } \| { queueId })` | move any call |
| `agent.setAvailability(value, { agentId })` | set an agent's availability |

Board events: `board` (the whole board, after each sync), `boardCall` (a call
appeared or changed), `boardCallEnded` (view, { terminationReason, terminatedBy }),
`counters` (the tenant's live counts, pushed at most every 2 s).

`agent.board` and the `board` / `boardCall` / `boardCallEnded` events are
supervisors' only. An agent whose tenant has the team view can page the board
with `boardCalls()`, but the SDK gives it no live board events.

A dashboard on a large tenant narrows and pages the board instead of holding
all of it:

| | |
|---|---|
| `agent.subscribeBoard({ channelIds?, queueIds?, agentIds? })` | only these lines / queues / agents from now on; `{}` = the whole tenant |
| `agent.unsubscribeBoard()` | no board on this connection |
| `agent.boardCalls({ …filter, cursor?, limit? })` | `{ calls, nextCursor }`, newest first |
| `agent.boardCounters()` | supervisors: the counters now |

`agent.board` is still rebuilt from `sync()` (the whole tenant); a narrowed
dashboard keeps its own list from `boardCalls()` and the board events.

A filter lasts for one connection: after a reconnect Calloop subscribes the new
connection to the whole tenant again. Re-apply it on `ready`:

```js
agent.on('ready', () => agent.subscribeBoard({ queueIds: [3] }));
```

```js
const monitor = await agent.monitor(callId);            // asks for the microphone
monitor.on('stream', (s) => { callAudio.srcObject = s; });   // the customer and the agent, mixed
monitor.setMode('whisper');                              // 'listen' | 'whisper' | 'barge'
monitor.mute(true);                                      // your microphone
monitor.stop();
```

A monitor has `callId`, `state` (`connecting` · `active` · `ended`), `mode`,
`muted` and `stream`.

`listen`: the supervisor hears the call, nobody hears the supervisor ·
`whisper`: the agent hears the supervisor · `barge`: both do. Calloop mixes, so
switching modes is instant. Monitor events: `state`, `stream` (the call as you
hear it), `mode`, `modeRefused` ({ mode, code, message }: Calloop refused a
`setMode()` — e.g. whisper on a direct call, or a mode the tenant doesn't allow
— and monitoring goes on in the current mode), `agentPrivate` (the agent
talking privately to you), `agentReconnected`, `ended` ({ reason, code?,
message? }). Reasons: `stopped`, `call_ended`, `ended` (Calloop ended it),
`disconnected`, `failed` (Calloop couldn't start it; `code`/`message` say why),
`not_allowed` (the tenant doesn't allow monitoring), `closed` (`agent.close()`).
A reconnect of the supervisor's socket ends monitoring — start it again.

## TypeScript

Types ship with the package: `connect`, `CalloopAgent`,
`Call`, `Monitor` and the payload shapes.

## What it handles

- Resync on every connect (`calls:sync`): ringing calls, calls on this device
  (reconnected automatically after a reload), calls on another device.
- ICE candidates buffered both ways until each side is ready.
- Media recovery: no media within 15 s or a failed connection → one reconnect.
  If that fails too, the call ends locally with `media_failed` and the SDK asks
  Calloop to end it (`system_failed`), so Calloop records it `FAILED` /
  `NETWORK_ERROR`.
- Direct calls (`call.isDirect`: a personal line's 1:1 call that Calloop relays
  without a room) reconnect like any other call (the SDK sends its own offer); `agent.monitor()` listens without
  the microphone — the stream carries the customer and the agent as two tracks
  (listen-only).
- Offers withdrawn (taken, timed out, declined elsewhere, an unaccepted
  transfer returned to its queue) and redelivered offers.
- TURN credentials refreshed on the live connection before they expire, for
  long shifts.

## A first test call

Sign a test token with your signing key ([the agent token](https://docs.calloop.net/agents/protocol#the-agent-token)),
connect as in [Connecting](#connecting), go available, and call your line.
