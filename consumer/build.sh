#!/usr/bin/env bash
# Builds both variants in Debug and Release for the iOS Simulator, then checks that only the
# Grafana variant links the package. Run scripts/publish-local.sh first.
set -euo pipefail

consumer="$(cd "$(dirname "$0")" && pwd)"
build="$consumer/build"
mirrors="$consumer/PackageConsumer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/mirrors.json"
if [[ ! -f "$mirrors" ]]; then
  echo "No local publication. Run scripts/publish-local.sh first." >&2
  exit 1
fi

for scheme in ConsumerGrafana ConsumerUpstream; do
  for configuration in Debug Release; do
    echo "Building $scheme ($configuration)"
    # Each local publication moves the same version tag to a new commit. Without the package
    # repository cache and with the fingerprint policy at `warn`, the build follows the move
    # instead of using the first commit it saw or failing on the changed revision.
    xcodebuild build \
      -quiet \
      -project "$consumer/PackageConsumer.xcodeproj" \
      -scheme "$scheme" \
      -configuration "$configuration" \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "$build/DerivedData" \
      -clonedSourcePackagesDirPath "$build/SourcePackages" \
      -disablePackageRepositoryCache \
      -packageFingerprintPolicy warn
  done
done

# Counts the Grafana package object files the linker was given for one app, across architectures.
# This checks the dependency graph rather than the binary, so dead stripping cannot hide a
# package that is still linked.
linked_package_objects() {
  local intermediates="$build/DerivedData/Build/Intermediates.noindex/PackageConsumer.build"
  local inputs
  inputs="$(find "$intermediates/$2-iphonesimulator/$1.build" -name "$1.LinkFileList" -exec cat {} +)"
  if [[ -z "$inputs" ]]; then
    echo "No link inputs found for $1 ($2)" >&2
    exit 1
  fi
  grep -c "/GrafanaOpenTelemetryIOS\.o$" <<<"$inputs" || true
}

for configuration in Debug Release; do
  grafana="$(linked_package_objects ConsumerGrafana "$configuration")"
  upstream="$(linked_package_objects ConsumerUpstream "$configuration")"
  # The Grafana count is the positive control. Without it, a change in Xcode's build layout could
  # let the removal check pass without checking anything.
  if [[ "$grafana" -eq 0 ]]; then
    echo "ConsumerGrafana ($configuration) does not link the package; the removal check cannot run" >&2
    exit 1
  fi
  if [[ "$upstream" -ne 0 ]]; then
    echo "ConsumerUpstream ($configuration) still links the Grafana package" >&2
    exit 1
  fi
  echo "Removal check ($configuration): only ConsumerGrafana links GrafanaOpenTelemetryIOS"
done
