# Grafana OpenTelemetry iOS

Grafana configuration for the upstream [OpenTelemetry Swift SDK](https://github.com/open-telemetry/opentelemetry-swift).
Application instrumentation uses standard OpenTelemetry APIs; this package is not an SDK fork.

**Development only.** No version of this package has been released.
`https://github.com/grafana/grafana-opentelemetry-ios` with the `GrafanaOpenTelemetryIOS` product is
the proposed identity. The `0.0.0-dev` version below is published only to a local Git repository for
validation, not a supported release.

## Source

The implementation and unit tests are extracted unchanged from
[`mobile-o11y-demo` #114](https://github.com/grafana/mobile-o11y-demo/pull/114), using the package at
[source revision `fa6ddbb`](https://github.com/grafana/mobile-o11y-demo/tree/fa6ddbb869696b3a62413dd3889ac7944018724d/Mobiles/ios/grafana-opentelemetry-ios).
That revision includes the later changes to the package: README alignment
([#117](https://github.com/grafana/mobile-o11y-demo/pull/117)) and the `opentelemetry-swift` `2.6.0`
update ([#133](https://github.com/grafana/mobile-o11y-demo/pull/133)).
This repository adds a standalone build, API checks and a separate package consumer.
It does not add new SDK behavior.

## Usage

See [configuration and initialization](docs/package.md) for requirements, defaults and known
limitations. The package requires `opentelemetry-swift` and `opentelemetry-swift-core` `2.6.0`, up to
the next minor version.

```swift
let runtime = try GrafanaOtel.initialize(
    configuration: try GrafanaOtelConfiguration(
        otlpEndpoint: URL(string: "https://collector.example/otlp/app-key")!,
        firstPartyHosts: ["api.my-app.example"],
        serviceVersion: "1.4.0"
    )
)
let tracer = runtime.openTelemetry.tracerProvider.get(
    instrumentationName: "com.example.app",
    instrumentationVersion: "1.0.0"
)
```

Initialize once, on the main thread, early in app startup. The first initialization owns the
process-wide runtime. No meter provider is registered; this package routes logs and traces to the
configured endpoint. Automatic `URLSession` tracing sends trace context only to `firstPartyHosts`.

## Build and Test

Use Xcode 26.6 or 27.0; CI runs both. The package declares iOS 13 and `swift-tools-version:6.0`.

```sh
swift test
xcodebuild test -scheme grafana-opentelemetry-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/xcodebuild-dd
scripts/api.sh check
scripts/publish-local.sh
consumer/build.sh
```

`swift test` runs on the macOS host, where MetricKit compiles out. The simulator run is authoritative.

`scripts/publish-local.sh` commits the working tree to a local Git repository in
`build/test-repository` and tags it `0.0.0-dev`. A Swift package release is a Git tag, so this is the
local equivalent of a publication. The script also adds a package mirror for the consumer project.
The [consumer](consumer/README.md) is a separate Xcode project. It resolves
`https://github.com/grafana/grafana-opentelemetry-ios.git` at exact version `0.0.0-dev` through that
mirror, not through a local path reference. Its upstream-only target uses the same application
instrumentation without a dependency on the Grafana layer. `consumer/build.sh` builds both targets in
Debug and Release and checks that only the Grafana target links the package.

`scripts/api.sh check` compares the public API with `api/GrafanaOpenTelemetryIOS.swiftinterface`. The
snapshot is the module's textual interface without private members. The compiler prints it, so CI
checks it only with Xcode 27.0, the version that wrote it. For an intentional API change, run
`scripts/api.sh dump` with Xcode 27.0 and review the changes to the snapshot together with the code
change. CI never updates the baseline automatically. This initial snapshot is not a promise of stable
APIs before release.

## Before a Release

- Agree the package identity, first release version, ownership and release workflow.
- Tag a release, then resolve it from a separate app by URL and tag, without the local mirror.
- Validate the packaged consumer against Faro ingest and connected backend traces.
- Verify removal of the Grafana layer in that same environment.
- Cover the supported iOS versions, down to the declared iOS 13 floor, and at least one physical
  device.

Local builds, unit tests and the consumer smoke test do not establish Grafana Cloud ingestion or
production readiness. No release workflow is included here. Open product decisions from the spike,
such as `device.id` and lifecycle instrumentation, are listed in its
[validation status](https://github.com/grafana/mobile-o11y-demo/blob/fa6ddbb869696b3a62413dd3889ac7944018724d/Mobiles/docs/GRAFANA_OPENTELEMETRY_IOS.md#validation-status).

## License

[Apache License 2.0](LICENSE).
