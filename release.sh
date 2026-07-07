#!/bin/bash
set -e
cd "$(dirname "$0")"

# Read version from Info.plist
VERSION=$(grep -A1 CFBundleShortVersionString Sources/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
TAG="v${VERSION}"
REPO="lifedever/health-tick-release"
GITEE_REPO="lifedever/health-tick-release"

echo "=== HealthTick Release ${TAG} ==="
echo ""

# Check if tag already exists on remote
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
    echo "Error: tag ${TAG} already exists. Bump version in Sources/Info.plist first."
    exit 1
fi

# Build for each architecture separately
echo "[1/6] Building binaries..."
swift build -c release --arch arm64
echo "  Built arm64"
swift build -c release --arch x86_64
echo "  Built x86_64"

# Package app bundles
echo "[2/6] Packaging apps..."
STAGE="/tmp/health-tick-release-${VERSION}"
rm -rf "$STAGE"

for label in Apple-Silicon Intel; do
    if [ "$label" = "Apple-Silicon" ]; then
        BIN=".build/arm64-apple-macosx/release/HealthTick"
    else
        BIN=".build/x86_64-apple-macosx/release/HealthTick"
    fi
    APP_DIR="${STAGE}/${label}/HealthTick.app/Contents"
    mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
    cp "$BIN" "$APP_DIR/MacOS/"
    cp Sources/Info.plist "$APP_DIR/"
    if [ -d "Sources/Resources" ]; then
        cp -R Sources/Resources/* "$APP_DIR/Resources/"
    fi
    codesign --force --deep --sign - "${STAGE}/${label}/HealthTick.app"
done

# Create DMGs
echo "[3/6] Creating DMGs..."
for label in Apple-Silicon Intel; do
    DMG_NAME="HealthTick-${TAG}-${label}.dmg"
    DMG_DIR="${STAGE}/dmg-${label}"
    mkdir -p "$DMG_DIR"
    cp -R "${STAGE}/${label}/HealthTick.app" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"
    hdiutil create -volname "HealthTick" -srcfolder "$DMG_DIR" -ov -format UDZO \
        "${STAGE}/${DMG_NAME}" -quiet
    echo "  Created ${DMG_NAME}"
done

# Git commit, tag, push
echo "[4/6] Pushing tag ${TAG}..."
git add -A
git diff --cached --quiet || git commit -m "${TAG}"
git tag "$TAG" 2>/dev/null || true
# Push only main + the new tag — never `--tags`, which would try to push every
# local tag and abort the release if any stale local tag conflicts with remote.
git push origin main "$TAG"
git push gitee main "$TAG" 2>/dev/null || echo "  Warning: failed to push to Gitee remote"

# Upload to GitHub release repo
echo "[5/6] Publishing release to GitHub ${REPO}..."
RELEASE_NOTES="## HealthTick ${TAG}

### 修复
- 修复休息窗口设为浮动卡片/全屏时，点「我去休息」会同时弹出所选窗口和主窗口两个窗口的问题 (#24 感谢 @Sunior)
- 修复浮动/全屏模式下休息提醒仍被显示在主窗口面板、且窗口比内容大的问题 (#24)
- 修复主窗口提醒被系统收起后长达 2 秒不可见的「秒闪」问题，现在半秒内恢复并校验窗口真实可见
- 修复启动后未点击过菜单栏图标时，主窗口模式的休息提醒完全不显示的问题
- 修复退出时正处于提醒状态、重启后提醒不再出现且计时停滞的问题
- 浮动模式下提醒弹出不再抢占键盘焦点

### 下载
- **Apple Silicon (M1/M2/M3/M4)**: \`HealthTick-${TAG}-Apple-Silicon.dmg\`
- **Intel**: \`HealthTick-${TAG}-Intel.dmg\`

### 安装方式
打开 \`.dmg\` 文件，将 HealthTick 拖入 Applications 文件夹。
首次打开请前往 **系统设置 → 隐私与安全性** 点击\"仍要打开\"。"

gh release create "$TAG" \
    --repo "$REPO" \
    --title "HealthTick ${TAG}" \
    --notes "$RELEASE_NOTES" \
    "${STAGE}/HealthTick-${TAG}-Apple-Silicon.dmg" \
    "${STAGE}/HealthTick-${TAG}-Intel.dmg"

echo "  GitHub release done"

# Upload to Gitee release repo
echo "[6/6] Publishing release to Gitee ${GITEE_REPO}..."
if [ -n "$GITEE_TOKEN" ]; then
    # Gitee v5 auth: access_token in the request body / form field ("Authorization:
    # token" headers return an HTML error page). JSON is built with python so the
    # multi-line release notes get escaped properly.
    GITEE_RELEASE_ID=$(RELEASE_NOTES="$RELEASE_NOTES" TAG="$TAG" GITEE_REPO="$GITEE_REPO" python3 - <<'PYEOF'
import json, os, urllib.request
data = json.dumps({
    "access_token": os.environ["GITEE_TOKEN"],
    "tag_name": os.environ["TAG"],
    "name": "HealthTick " + os.environ["TAG"],
    "body": os.environ["RELEASE_NOTES"],
    "target_commitish": "main",
}).encode()
req = urllib.request.Request(
    "https://gitee.com/api/v5/repos/" + os.environ["GITEE_REPO"] + "/releases",
    data=data, headers={"Content-Type": "application/json"})
try:
    print(json.load(urllib.request.urlopen(req)).get("id", ""))
except Exception:
    print("")
PYEOF
)

    if [ -n "$GITEE_RELEASE_ID" ]; then
        for label in Apple-Silicon Intel; do
            DMG_FILE="${STAGE}/HealthTick-${TAG}-${label}.dmg"
            curl -s -X POST \
                "https://gitee.com/api/v5/repos/${GITEE_REPO}/releases/${GITEE_RELEASE_ID}/attach_files" \
                -F "access_token=${GITEE_TOKEN}" \
                -F "file=@${DMG_FILE}" > /dev/null
            echo "  Uploaded HealthTick-${TAG}-${label}.dmg to Gitee"
        done
        echo "  Gitee release done"
    else
        echo "  Warning: Failed to create Gitee release"
    fi
else
    echo "  Skipped (no GITEE_TOKEN env var set)"
    echo "  To enable: export GITEE_TOKEN=your_gitee_personal_access_token"
fi

echo ""
echo "=== Done! Released ${TAG} ==="
echo "GitHub: https://github.com/${REPO}/releases/tag/${TAG}"
echo "Gitee:  https://gitee.com/${GITEE_REPO}/releases/tag/${TAG}"

# Cleanup
rm -rf "$STAGE"
