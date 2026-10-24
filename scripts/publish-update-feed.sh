#!/usr/bin/env bash
# Store signed, per-release appcasts without adding them to GitHub Release assets.
set -euo pipefail
feed="${1:?Signed appcast path is required}"
tag="${2:?Release tag is required}"
if [[ ! "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+-(alpha|beta|rc)\.?[0-9]+$ && ! "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' 'Unsupported release tag' >&2
    exit 1
fi
feed_blob="$(git hash-object -w "$feed")"
index_dir="$(mktemp -d)"
trap 'rm -rf "$index_dir"' EXIT
export GIT_INDEX_FILE="$index_dir/index"
branch=sparkle-feeds
commit_tree() {
    git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
        commit-tree "$tree" "$@" -m "chore: publish signed macOS feed for $tag"
}
for attempt in 1 2 3 4 5; do
    parent=""
    if git ls-remote --exit-code --heads origin "$branch" > "$index_dir/remote"; then
        git fetch --no-tags origin "refs/heads/$branch"
        parent="$(git rev-parse FETCH_HEAD)"
        git read-tree "$parent"
    else
        status=$?
        if [[ "$status" != 2 ]]; then exit "$status"; fi
        git read-tree --empty
    fi
    git update-index --add --cacheinfo "100644,$feed_blob,updates/macos/$tag.xml"
    tree="$(git write-tree)"
    if [[ -n "$parent" ]]; then
        if [[ "$tree" == "$(git rev-parse "$parent^{tree}")" ]]; then exit 0; fi
        commit="$(commit_tree -p "$parent")"
    else
        commit="$(commit_tree)"
    fi
    if git push origin "$commit:refs/heads/$branch"; then exit 0; fi
    # A concurrent release may have published another feed. Merge its tree and retry.
done
printf '%s\n' 'Could not publish update feed after five attempts' >&2
exit 1
