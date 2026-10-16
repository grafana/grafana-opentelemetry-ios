#!/usr/bin/env bash
# Publishes the working tree as version 0.0.0-dev of a local Git repository, so the consumer
# resolves the package by URL and version, as an app would after a release.
#
# Swift Package Manager has no local publication step. A release is a Git tag, so this writes one
# commit and tag to build/test-repository and maps the GitHub URL to it with a package mirror.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="0.0.0-dev"
repository="$root/build/test-repository/grafana-opentelemetry-ios.git"
swiftpm="$root/consumer/PackageConsumer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"

# The consumer's package checkouts go too: each publication moves the same tag to a new commit, and
# an existing clone would not follow it.
rm -rf "$repository" "$swiftpm" "$root/consumer/build/SourcePackages"
mkdir -p "$(dirname "$repository")" "$swiftpm/configuration"
git init --quiet --bare "$repository"

# The bare repository is the Git directory and the checkout is the work tree, so the commit holds
# the working tree as `git add -A` sees it: uncommitted edits included, ignored files excluded.
publication=(git --git-dir="$repository" --work-tree="$root")
"${publication[@]}" add --all
tree="$("${publication[@]}" write-tree)"
commit="$(
  GIT_AUTHOR_NAME="Local publication" GIT_AUTHOR_EMAIL="local@localhost" \
  GIT_COMMITTER_NAME="Local publication" GIT_COMMITTER_EMAIL="local@localhost" \
  GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
    "${publication[@]}" commit-tree "$tree" -m "Local publication $version"
)"
"${publication[@]}" update-ref refs/heads/main "$commit"
"${publication[@]}" symbolic-ref HEAD refs/heads/main
"${publication[@]}" tag "$version" "$commit"

cat > "$swiftpm/configuration/mirrors.json" <<EOF
{
  "object" : [
    {
      "mirror" : "file://$repository",
      "original" : "https://github.com/grafana/grafana-opentelemetry-ios.git"
    }
  ],
  "version" : 1
}
EOF

# Start from the package's own pins, so the consumer builds against the upstream revisions the
# package was tested with. Resolution adds the pin for this publication.
cp "$root/Package.resolved" "$swiftpm/Package.resolved"

echo "Published $version at $commit to $repository"
