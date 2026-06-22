#!/bin/zsh
# 사용법: ./release.sh v1.1.0 "변경사항 설명"

VERSION=$1
NOTES=$2

if [[ -z "$VERSION" ]]; then
  echo "버전을 입력해주세요. 예: ./release.sh v1.1.0 \"변경사항\""
  exit 1
fi

SCHEME="B_Side"
ZIP_NAME="B-Side-${VERSION}.zip"
ZIP_PATH="$HOME/Desktop/$ZIP_NAME"

echo "▶ 빌드 중..."
xcodebuild -scheme "$SCHEME" -configuration Release build 2>&1 | grep -E "error:|BUILD"

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/B_Side-* -path "*/Release/B_Side.app" -maxdepth 8 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "✗ 빌드된 앱을 찾을 수 없습니다."
  exit 1
fi

echo "▶ 패키징 중..."
xattr -cr "$APP_PATH"
cd "$(dirname "$APP_PATH")"
zip -r "$ZIP_PATH" B_Side.app > /dev/null
echo "  → $ZIP_PATH ($(du -sh "$ZIP_PATH" | cut -f1))"

echo "▶ GitHub Release 생성 중..."
cd "$(dirname "$0")"
gh release create "$VERSION" "$ZIP_PATH" \
  --title "B-Side $VERSION" \
  --notes "${NOTES:-$VERSION}"

echo "✓ 완료!"
