#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_NAME="AgentDeck"
APP_BUNDLE="${ROOT_DIR}/dist/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"
EXECUTABLE_SOURCE="${ROOT_DIR}/.build/arm64-apple-macosx/${BUILD_CONFIG}/${APP_NAME}"

cd "${ROOT_DIR}"

swift build -c "${BUILD_CONFIG}"

if [[ ! -x "${EXECUTABLE_SOURCE}" ]]; then
  EXECUTABLE_SOURCE="${ROOT_DIR}/.build/${BUILD_CONFIG}/${APP_NAME}"
fi

if [[ ! -x "${EXECUTABLE_SOURCE}" ]]; then
  echo "Cannot find built executable for ${APP_NAME}." >&2
  exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${EXECUTABLE_SOURCE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>AgentDeck</string>
  <key>CFBundleExecutable</key>
  <string>AgentDeck</string>
  <key>CFBundleIdentifier</key>
  <string>local.agentdeck.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>AgentDeck</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null

rm -rf "${INSTALL_PATH}"
cp -R "${APP_BUNDLE}" "${INSTALL_PATH}"

echo "Installed ${INSTALL_PATH}"
