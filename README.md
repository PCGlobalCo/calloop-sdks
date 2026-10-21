# Calloop SDKs

Client SDKs for [Calloop](https://docs.calloop.net): take the WhatsApp and SIP
calls Calloop routes to your agents, in the browser, in React or in Flutter.

| Package | Install | Docs |
|---|---|---|
| [`@calloop/agent-sdk`](agent-js) — browsers and Node | `npm install @calloop/agent-sdk` | [docs.calloop.net/sdks/js](https://docs.calloop.net/docs/sdks/js) |
| [`@calloop/agent-react`](agent-react) — React provider and hooks | `npm install @calloop/agent-react @calloop/agent-sdk` | [docs.calloop.net/sdks/react](https://docs.calloop.net/docs/sdks/react) |
| [`calloop_agent`](agent-dart) — Flutter | `flutter pub add calloop_agent` | [docs.calloop.net/sdks/dart](https://docs.calloop.net/docs/sdks/dart) |

The SDKs connect with a short-lived **agent token** that your backend signs
with one of your signing keys — never with an API key. See
[the agent token](https://docs.calloop.net/docs/agents/protocol#the-agent-token).

## Issues and contributions

Report bugs and ask for features in [Issues](https://github.com/PCGlobalCo/calloop-sdks/issues).
This repository is published from Calloop's internal repository; pull
requests are welcome, and an accepted change is applied there and arrives
here with the next sync.

## License

MIT — see each package's `LICENSE`.
