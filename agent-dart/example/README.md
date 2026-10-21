# calloop_agent example

A minimal agent app on `calloop_agent` (Android). It connects with an agent
token and lets the agent go available, then answer, decline, mute or hang up.
When the app isn't in front, calls ring on the phone's native call screen.

Get a token (on the Calloop server):

```bash
npm run -s agent:token -- --consumer midlr-dev --tenant 103 --agent 110 --minutes 720
```

Run it on a connected phone (`flutter devices`):

```bash
flutter run --dart-define=CALLOOP_URL=https://api.calloop.net --dart-define=CALLOOP_TOKEN=eyJ...
```

Without `CALLOOP_TOKEN` the app asks for the URL and token on its first
screen. `CALLOOP_DEVICE_ID` sets the device id (default `android-example`).

For convenience only, the example signs release builds with the debug key and
takes the token through `--dart-define=CALLOOP_TOKEN` (which ends up in the
app binary). Never ship an app that way: sign with your own release key, and
fetch short-lived tokens from your backend at runtime (`getToken`, see the
SDK's README, Security).
