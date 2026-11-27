#!/bin/bash
set -euo pipefail

tag=${GITHUB_REF_NAME:?}
cd dist
dmg="GlassNotes-${tag#v}-arm64.dmg"
sha256sum --check "$dmg.sha256"
digest=$(sha256sum "$dmg" | cut -d ' ' -f 1)

tag_commit=$(gh api "repos/$GH_REPO/commits/$tag" --jq .sha)
if [[ "$tag_commit" != "$(git rev-parse HEAD)" ]]; then
    echo "::error::Tag $tag no longer points to the commit that built this DMG"
    exit 1
fi

# A retry may find a partially uploaded draft or an already published release.
state=$(gh api graphql -f owner="${GH_REPO%/*}" -f repo="${GH_REPO#*/}" -f tag="$tag" \
    -f query='query($owner:String!, $repo:String!, $tag:String!) {
      repository(owner:$owner, name:$repo) { release(tagName:$tag) { isDraft } }
    }' --jq '.data.repository.release | if . == null then "new" elif .isDraft then "draft" else "published" end')

if [[ "$state" == new ]]; then
    gh release create "$tag" --draft --verify-tag --target "$tag_commit" --generate-notes --title "GlassNotes ${tag#v}" \
        --notes '适用于 macOS 14 及以上的 Apple 芯片 Mac。退出 GlassNotes，打开 DMG，将应用拖入「应用程序」。此构建使用 ad hoc 签名，未经 Apple 公证。'
fi
if [[ "$state" != published ]]; then
    gh release upload "$tag" "$dmg" "$dmg.sha256" --clobber
fi

gh release view "$tag" --json assets | jq -e --arg dmg "$dmg" --arg digest "sha256:$digest" \
    'any(.assets[]; .name == $dmg and .digest == $digest)' >/dev/null || {
    echo "::error::Release asset $dmg does not match the verified build"
    exit 1
}
if [[ "$state" != published ]]; then
    gh release edit "$tag" --draft=false
fi
