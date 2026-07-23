#!/bin/zsh
# 사용법: ./release.sh v1.2.0 "변경사항 설명"

VERSION=$1
NOTES=$2
REPO_DIR="${0:A:h}"

if [[ -z "$VERSION" ]]; then
  echo "버전을 입력해주세요. 예: ./release.sh v1.2.3 \"변경사항\""
  exit 1
fi

SCHEME="B_Side"
PLIST_PATH="$REPO_DIR/B_Side/Info.plist"
VERSION_NUM="${VERSION#v}"
STAGING_DIR="$HOME/Desktop/B-Side-staging"
DMG_NAME="B-Side-${VERSION}.dmg"
DMG_PATH="$HOME/Desktop/$DMG_NAME"

echo "▶ Info.plist 버전 업데이트 ($VERSION_NUM)..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NUM" "$PLIST_PATH"

echo "▶ 빌드 중..."
xcodebuild -scheme "$SCHEME" -configuration Release \
  MARKETING_VERSION="$VERSION_NUM" \
  CURRENT_PROJECT_VERSION="$VERSION_NUM" \
  clean build 2>&1 | grep -E "error:|BUILD"

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/B_Side-* -path "*/Release/B_Side.app" -maxdepth 8 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "✗ 빌드된 앱을 찾을 수 없습니다."
  exit 1
fi

EMBEDDED=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null | tr -d '[:space:]')
echo "  → 앱 내부 버전: $EMBEDDED"

if [[ "$EMBEDDED" != "$VERSION_NUM" ]]; then
  echo "✗ 버전 불일치! 빌드 캐시 문제. 다시 시도해주세요."
  exit 1
fi

echo "▶ DMG 생성 중..."
INSTALLER_DIR="$REPO_DIR/installer"
BG_IMAGE="$INSTALLER_DIR/dmg_background.png"
RW_DMG="$HOME/Desktop/B-Side-rw.dmg"

rm -rf "$STAGING_DIR" "$DMG_PATH" "$RW_DMG"
mkdir -p "$STAGING_DIR"
xattr -cr "$APP_PATH"
cp -r "$APP_PATH" "$STAGING_DIR/B_Side.app"
ln -s /Applications "$STAGING_DIR/Applications"

# 읽기/쓰기 DMG 생성
hdiutil create \
  -volname "B-Side $VERSION_NUM" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG" > /dev/null

rm -rf "$STAGING_DIR"

# DMG 마운트
MOUNT_POINT=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen 2>/dev/null \
  | grep "/Volumes" | sed 's/.*\/Volumes\//\/Volumes\//')
echo "  → 마운트: $MOUNT_POINT"
sleep 1

# 배경 이미지 복사
mkdir -p "$MOUNT_POINT/.background"
cp "$BG_IMAGE" "$MOUNT_POINT/.background/background.png"

# AppleScript로 창 레이아웃 설정
osascript << APPLESCRIPT
tell application "Finder"
  tell disk "B-Side $VERSION_NUM"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 560}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 100
    set background picture of viewOptions to file ".background:background.png"
    set position of item "B_Side.app" of container window to {160, 270}
    set position of item "Applications" of container window to {500, 270}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

# DMG 언마운트
hdiutil detach "$MOUNT_POINT" -quiet
sleep 1

# 읽기 전용 압축 DMG로 변환
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" > /dev/null
rm -f "$RW_DMG"

echo "  → $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"

echo "▶ /Applications 업데이트 중..."
pkill "B_Side" 2>/dev/null || true
sleep 0.5
rm -rf /Applications/B_Side.app
cp -r "$APP_PATH" /Applications/B_Side.app
xattr -cr /Applications/B_Side.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/B_Side.app
open /Applications/B_Side.app
echo "  → 앱 재시작 완료"

echo "▶ GitHub Release 생성 중..."
cd "$REPO_DIR"
gh release create "$VERSION" "$DMG_PATH" \
  --title "B-Side $VERSION" \
  --notes "${NOTES:-$VERSION}"

echo "✓ 완료!"
