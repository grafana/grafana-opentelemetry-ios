# Independent Package Consumer

This is a test fixture, not a production application. Run `scripts/publish-local.sh` from the
repository root before building this project. The package manifest does not reference this directory.

- `ConsumerGrafana` resolves `https://github.com/grafana/grafana-opentelemetry-ios.git` at exact
  version `0.0.0-dev`. The publish script maps that URL to `../build/test-repository` with a package
  mirror. It also starts resolution from the package's own `Package.resolved`, so both builds use the
  same upstream revisions. Each publication moves the tag, so `build.sh` sets the package
  fingerprint policy to `warn`.
- `ConsumerUpstream` depends on `opentelemetry-swift` and `opentelemetry-swift-core` directly, with no
  Grafana dependency.
- `Sources/Shared` contains the identical application instrumentation for both targets.
- Only the dependencies and startup (`Sources/Grafana` and `Sources/Upstream`) differ. The upstream
  target is a removal check, not a claim that all Grafana startup defaults are kept. For example, it
  has no automatic `URLSession` tracing or sessions.
- Debug and whole-module-optimized Release builds are ad hoc signed for the iOS Simulator. Do not
  distribute them.

On launch, the app emits a client span and a log through standard OpenTelemetry APIs. It sends a
request to `http://127.0.0.1:8089/probe` with W3C trace context, and exports OTLP to
`http://127.0.0.1:4318`. The simulator shares the host's loopback network. `Info.plist` permits local
HTTP only for this fixture. Disk buffering is disabled here to make local delivery observable.

The app injects trace context itself, so in both targets the backend span's parent is the client
span. In the Grafana target, automatic `URLSession` tracing also records a child HTTP span. Upstream
keeps headers that are already on a request, so it does not replace the injected context.

To test end-to-end traces, run an OTLP receiver and an instrumented backend at those addresses,
install either app and launch it. Confirm the client's trace ID is connected to the backend span, not
merely that both services emit telemetry. Repeat for the Release build and the upstream-only target.
A local receiver is not evidence of successful Faro or Grafana Cloud ingest; those need their own
validation before release.

For a repeatable local check, leave host ports 4318 and 8089 free and use a dedicated simulator:

```sh
python3 -m venv build/smoke-venv
build/smoke-venv/bin/pip install -r consumer/smoke-requirements.txt
udid="$(xcrun simctl create package-consumer-smoke "iPhone 17" com.apple.CoreSimulator.SimRuntime.iOS-27-0)"
xcrun simctl bootstatus "$udid" -b
build/smoke-venv/bin/python consumer/smoke_test.py --udid "$udid"
xcrun simctl shutdown "$udid" && xcrun simctl delete "$udid"
```

Run these commands from the repository root after `consumer/build.sh`. The test binds loopback-only
receivers, installs the fixture apps, and checks that exported logs and client spans correlate with an
instrumented local backend span. For the Grafana target, it also checks `session.id`, the stable HTTP
attribute names, and that the recorded URL has no query string. It stops the fixture apps and servers
afterward and leaves the apps installed. The script does not create, boot or delete the simulator. It
never contacts a cloud collector.
