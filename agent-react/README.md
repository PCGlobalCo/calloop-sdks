# @calloop/agent-react

React bindings for [`@calloop/agent-sdk`](https://docs.calloop.net/docs/sdks/js): a provider
that connects once, and hooks that re-render when calls, availability, queues
or the supervisor board change. The SDK's objects and actions are used as they
are — this package only wires them into React. React 18+.

```sh
npm install @calloop/agent-react @calloop/agent-sdk
```

```jsx
import { CalloopProvider, useAgent, useIncomingCalls, useActiveCall, useCall, RemoteAudio } from '@calloop/agent-react';

export default function App() {
  return (
    <CalloopProvider url="https://api.calloop.net" getToken={() => fetch('/api/calloop-token').then((r) => r.text())}>
      <AgentScreen />
    </CalloopProvider>
  );
}

function AgentScreen() {
  const { me, availability, setAvailability } = useAgent();
  const ringing = useIncomingCalls();
  const active = useActiveCall();
  return (
    <>
      <p>{me?.name} — {availability}</p>
      <button onClick={() => setAvailability('AVAILABLE')}>Available</button>
      {ringing.map((call) => <Ringing key={call.id} call={call} />)}
      {active && <OnCall call={active} />}
    </>
  );
}

function Ringing({ call }) {
  const { customer, accept, decline } = useCall(call);
  return <div>{customer.address} <button onClick={() => accept()}>Answer</button> <button onClick={decline}>Decline</button></div>;
}

function OnCall({ call }) {
  const { state, customer, remoteStream, muted, mute, hangup, transfer } = useCall(call);
  return (
    <div>
      {customer.address} — {state}
      <RemoteAudio stream={remoteStream} />
      <button onClick={() => mute(!muted)}>{muted ? 'Unmute' : 'Mute'}</button>
      <button onClick={() => transfer({ queueId: 3 })}>Transfer</button>
      <button onClick={hangup}>Hang up</button>
    </div>
  );
}
```

## Security

The rules of the [JS SDK](https://docs.calloop.net/docs/sdks/js#security) apply: only
short-lived agent tokens from your backend in the browser (never an API key),
`getToken` for a fresh one on every connect, `role` on every token, https only.

In development, sign the tokens with your **test** signing key (`kid` `test_…`): same
`url`, same component, free simulated test calls
([Testing your integration](https://docs.calloop.net/docs/guide/testing)).

## Provider

`<CalloopProvider>` takes `connect()`'s options (`url`, `token` | `getToken`,
`deviceId`, `webrtc`, `getUserMedia`, `purpose`, `io`) or `agent` — an already
connected `CalloopAgent`. `connect` replaces the SDK's `connect()` (e.g. in
tests). The latest `token` / `getToken` is used on every (re)connect,
so passing a fresh token doesn't reconnect; only another `url` or `deviceId`
does. A connection the provider made closes on unmount; an `agent` passed in
is left open — close it yourself.

## Hooks

| Hook | Returns |
|---|---|
| `useCalloop()` | `{ agent, status, error }` — `status`: `connecting` · `ready` · `reconnecting` · `closed` · `error`. `closed`: Calloop ended the connection and won't take it back (e.g. the token's signing key was revoked; `error` says why) — remount the provider (e.g. change its `key`) to connect again |
| `useAgent()` | `{ agent, me, tenant, availability, isSupervisor, setAvailability(value, { agentId? }) }` — `agent` is the SDK's `CalloopAgent` |
| `useCalls()` | this agent's calls (SDK `Call` objects) |
| `useIncomingCalls()` | the ringing ones |
| `useActiveCall()` | the call being set up / on / dialing, or `null` |
| `useCall(call)` | `{ call, state, data, customer, remoteStream, muted, lastDigit, endReason, accept, decline, hangup, mute, transfer, setPrivate, switchHere }` — `lastDigit`: the customer's last key press |
| `useQueues()` | queue snapshots (supervisors, and agents whose tenant allows the team view; otherwise empty) |
| `useTeam()` | the tenant's agents' availability (likewise; otherwise only this agent) |
| `useBoard()` | supervisors: the tenant's live calls |
| `useMonitor(callId)` | supervisors: `{ monitor, state, mode, stream, error, start(), stop(), setMode(), mute() }` — `state`: `idle` · `connecting` · `active`, back to `idle` when monitoring ends; `stream` is the call as they hear it; stops on unmount. `error`: `start()` rejected, Calloop refused or failed the monitor (it then ended; `error.code` is Calloop's), or refused a `setMode()` (monitoring goes on in the current mode; cleared by the next mode change) |

`<RemoteAudio stream />` plays a stream (a call's `remoteStream`, a monitor's
`stream`); other props go to the `<audio>` element.

## Supervisor screen

```jsx
import { useEffect, useState } from 'react';
import { useBoard, useMonitor, RemoteAudio } from '@calloop/agent-react';

function Board() {
  const calls = useBoard();
  const [watching, setWatching] = useState(null);
  return (
    <>
      {calls.map((c) => (
        <div key={c.callId}>
          {c.customer?.address} · {c.status} · {c.agentName ?? 'waiting'} {c.ivr && `· IVR ${c.ivr.nodeType}`}
          <button onClick={() => setWatching(c.callId)}>Listen</button>
        </div>
      ))}
      {watching && <Listening callId={watching} />}
    </>
  );
}

function Listening({ callId }) {
  const { state, mode, stream, start, setMode, stop } = useMonitor(callId);
  useEffect(() => { start(); }, [start]);
  return (
    <div>
      {state} · {mode}
      <RemoteAudio stream={stream} />
      <button onClick={() => setMode('whisper')}>Whisper</button>
      <button onClick={() => setMode('barge')}>Barge</button>
      <button onClick={stop}>Stop</button>
    </div>
  );
}
```

## No build step

The package is plain ES modules (`React.createElement`, no JSX) with
TypeScript types, so any bundler takes it as is.
