## 0.1.1

* Docs links fixed: they point to docs.calloop.net/docs/… (the old ones gave 404).
* First release published by GitHub Actions from [PCGlobalCo/calloop-sdks](https://github.com/PCGlobalCo/calloop-sdks).

## 0.1.0

* First public release.

* Security: a release build refuses a gateway URL that isn't https / wss
  (`ArgumentError`; `localhost`, `127.0.0.1`, `::1` and `10.0.2.2` excepted);
  a debug build allows it with a warning.
* Security: `CalloopNativeCalls` applies a native Accept / Decline only to a
  call whose native screen this device showed (by the SDK, or still listed by
  the plugin, e.g. from `handlePush`); other taps are ignored and logged. The
  45 s `pendingFor` wait is unchanged.
* README: a Security section — short-lived agent tokens only (never an API
  key), a fresh token in `getToken`, `flutter_secure_storage`, https / wss,
  `flutter_callkit_incoming` >= 3.1.6, Calloop's 24-hour token limit and the
  default `AGENT` role, the generic push title. The example's README warns that
  its release signing and `CALLOOP_TOKEN` define are for convenience only.
