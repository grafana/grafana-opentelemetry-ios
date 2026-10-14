# Extraction Validation

Local validation on October 14, 2026. This is not release approval or Grafana Cloud ingestion evidence.

## Environment

- macOS 27.0.1 arm64, Xcode 27.0 (27A266a), Swift 6.4.
- iOS 26.5 and iOS 27.0 simulator runtimes.
- `opentelemetry-swift` 2.6.0 and `opentelemetry-swift-core` 2.6.0, from the extracted
  `Package.resolved`, preserving the spike's dependencies.
- Python 3.14.5 with the pinned smoke-test dependencies.
- Local OTLP receiver and instrumented Python backend; no cloud collector.

## Confirmed

### Source preservation

`Package.swift`, `Package.resolved`, `Sources` and `Tests` match
`Mobiles/ios/grafana-opentelemetry-ios` at `mobile-o11y-demo` revision
`fa6ddbb869696b3a62413dd3889ac7944018724d` byte for byte. That revision includes every merged change to
the package after #114: #117 (README alignment) and #133 (`opentelemetry-swift` 2.6.0). No SDK
behavior was changed. The package README moved to `docs/package.md`. Its edits are for the new
repository only: the introduction, the verified toolchains, the test commands and the links.

### Library tests

```sh
swift test
xcodebuild test -scheme grafana-opentelemetry-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath .build/xcodebuild-dd
```

Expected: all package tests pass on the macOS host and on the iOS Simulator. Actual: 94 tests and zero
failures on the macOS host, on an iPhone 17 Pro with iOS 26.5, and on an iPhone 18 Pro with iOS 27.0.

Swift 6.4 reports four warnings in the extracted code: two unnecessary `try` markers in
`GrafanaOtel.swift`, an inferred `AnyClass?` and an unused value in the tests. They were kept, so that
the extracted source stays identical to the spike.

### Public API

```sh
scripts/api.sh dump
scripts/api.sh check
```

Expected: the check passes against the committed snapshot and fails on any public API change. Actual:
passed. Negative test: temporarily renamed `GrafanaOtel.runtime` to `currentRuntime` and ran the check.
It failed with the exact removed and added declaration. Restored the source, verified byte equality
with the spike, and reran the check successfully. The API baseline was not changed to accept the
mutation.

A library-evolution build fails in the upstream `swift-log` dependency, so the snapshot uses the
module's default interface with private members removed. Swift packages compile from source, so the
snapshot checks source compatibility, not binary compatibility.

### Independent consumer

```sh
scripts/publish-local.sh
consumer/build.sh
```

Expected: both targets compile in Debug and Release for the iOS Simulator. The Grafana target resolves
the package by URL and exact version, not a local path. Actual: all four apps built. Xcode fetched the
local repository through the package mirror and checked out tag `0.0.0-dev`. Every upstream pin
matched the package's `Package.resolved`; the only added pin was the local publication.

The upstream target's link inputs contain no `GrafanaOpenTelemetryIOS` object in either
configuration, and the Grafana target's do. Both targets compile the identical `Sources/Shared`
instrumentation; only startup and dependencies differ.

Republishing after a change moves the `0.0.0-dev` tag to a new commit. An existing package checkout
kept the first commit, so the publish script deletes the consumer's checkouts. SwiftPM's fingerprint
store then failed the build on the changed revision, so `consumer/build.sh` sets
`-packageFingerprintPolicy warn`. With both, a rebuild checked out the new commit.

Negative removal test: temporarily linked the `GrafanaOpenTelemetryIOS` product into
`ConsumerUpstream`, without using it from code. `consumer/build.sh` failed with "ConsumerUpstream
(Debug) still links the Grafana package". Restored the project file and verified byte equality. The
check reads link inputs rather than binary symbols, so dead stripping cannot hide an unused link.

### Runtime smoke test

On a new iPhone 17 Pro simulator with iOS 26.5 and a new iPhone 17 simulator with iOS 27.0:

```sh
build/smoke-venv/bin/python consumer/smoke_test.py --udid UDID
```

Use the virtual environment and dependencies described in `consumer/README.md`. Expected: every
target and configuration exports a log and client span, and the instrumented local backend span has
the same trace ID and the client span as its parent. Actual: all four combinations passed on both
simulators. Logs carried the matching trace ID. The harness also verifies the service name and rejects
an error status on the client span.

For the Grafana target, the harness also checks the package defaults that a packaged build must keep.
The client span carried `session.id`. The automatic `URLSession` span was a child of the client span,
with `http.request.method` set and `url.full` recorded without the probe's query string.

Two mutated copies of the harness confirmed that these checks can fail. Expecting the query string in
`url.full` failed and printed the recorded attributes. Requiring an automatic HTTP span from the
upstream target failed with missing telemetry, because that target has no `URLSession`
instrumentation. Both simulators were deleted after testing.

### Workflow

`actionlint` 1.7.12, with `shellcheck` 0.11.0, passed for `.github/workflows/validate.yml`.
`shellcheck` passed for the three scripts. The workflow commands passed locally with Xcode 27.0. The
workflow has not been run on GitHub in this extraction branch, so the Xcode 26.6 job is untested.

## Not Yet Verified

- The Xcode 26.6 CI job. The spike was validated on that toolchain, but these scripts have only run
  with Xcode 27.0.
- The `xcode-27` runner image, which GitHub still marks as a preview.
- A release tag on this repository, and resolution from GitHub without the local mirror.
- Faro acceptance and querying of the packaged consumer's telemetry in Grafana.
- Connected backend traces and removal checks in that same Grafana environment.
- Physical devices, iOS versions other than 26.5 and 27.0, and the declared iOS 13 floor.
- Disk buffering, MetricKit delivery and redirect protection in the packaged consumer.

The smoke fixture disables disk buffering for deterministic delivery and uses loopback HTTP. It does
not validate authenticated HTTPS cloud ingest, network retry or durability behavior, or a full
production application. Existing unit tests cover the retained initialization and configuration
behavior; they do not replace these release gates.
