#!/usr/bin/env bash

# Exit immediately on any error
set -e

# ANSI color codes
GREEN="\033[1;32m"
LIGHT_BLUE="\033[1;34m"
RED="\033[1;31m"
NC="\033[0m"  # No Color

# Log functions with colors
success() {
  echo -e "\n${GREEN}[RELEASE] $1${NC}"
}
info() {
  echo -e "\n${LIGHT_BLUE}[RELEASE] $1${NC}"
}
error() {
  echo -e "\n${RED}[RELEASE] $1${NC}"
}

#####################################
# 1. 提取 pubspec.yaml 版本号
#####################################
info "Extracting version from pubspec.yaml..."
PUBSPEC_VERSION=$(grep -m 1 '^version:' pubspec.yaml | sed 's/version:\s*//' | xargs)
if [ -z "$PUBSPEC_VERSION" ]; then
  error "ERROR: Could not find 'version:' in pubspec.yaml"
  exit 1
fi

VERSION_PART=$(echo "$PUBSPEC_VERSION" | cut -d '+' -f1)
BUILD_PART=$(echo "$PUBSPEC_VERSION" | cut -d '+' -f2)

if [ -z "$BUILD_PART" ]; then
  error "ERROR: pubspec.yaml version does not include a build number (e.g. +45)."
  exit 1
fi

CURRENT_TAG="${VERSION_PART}+${BUILD_PART}"
info "Current version: $VERSION_PART+$BUILD_PART"

#####################################
# 2. 检查 tag 是否已存在，若存在则交互式升版
#####################################
info "Fetching latest tags from remote..."
git fetch --tags

NEW_VERSION_FULL=""

if git rev-parse "$CURRENT_TAG" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "$CURRENT_TAG" >/dev/null 2>&1; then
  error "Tag '$CURRENT_TAG' already exists locally or on remote."

  echo ""
  info "Would you like to automatically bump the version?"
  echo "1) Bump patch version (default) - $VERSION_PART -> $(echo $VERSION_PART | awk -F. '{$NF = $NF + 1;} 1' | sed 's/ /./g')"
  echo "2) Bump minor version - $VERSION_PART -> $(echo $VERSION_PART | awk -F. '{$2 = $2 + 1; $3 = 0;} 1' | sed 's/ /./g')"
  echo "3) Bump major version - $VERSION_PART -> $(echo $VERSION_PART | awk -F. '{$1 = $1 + 1; $2 = 0; $3 = 0;} 1' | sed 's/ /./g')"
  echo "4) Only bump build number - $VERSION_PART+$BUILD_PART -> $VERSION_PART+$((BUILD_PART + 1))"
  echo "5) Exit"
  read -p "Choose an option (1-5) [1]: " choice
  choice=${choice:-1}

  case $choice in
    1)
      NEW_VERSION=$(echo $VERSION_PART | awk -F. '{$NF = $NF + 1;} 1' | sed 's/ /./g')
      ;;
    2)
      NEW_VERSION=$(echo $VERSION_PART | awk -F. '{$2 = $2 + 1; $3 = 0;} 1' | sed 's/ /./g')
      ;;
    3)
      NEW_VERSION=$(echo $VERSION_PART | awk -F. '{$1 = $1 + 1; $2 = 0; $3 = 0;} 1' | sed 's/ /./g')
      ;;
    4)
      NEW_VERSION=$VERSION_PART
      ;;
    5)
      info "Exiting..."
      exit 1
      ;;
    *)
      error "Invalid option. Exiting."
      exit 1
      ;;
  esac

  NEW_BUILD=$((BUILD_PART + 1))
  NEW_VERSION_FULL="$NEW_VERSION+$NEW_BUILD"
  info "New version will be: $NEW_VERSION_FULL"

  info "Updating pubspec.yaml with new version..."
  sed -i '' "s/^version: .*$/version: $NEW_VERSION_FULL/" pubspec.yaml
  success "Updated pubspec.yaml to version $NEW_VERSION_FULL"

  #####################################
  # 3. 提交并推送版本号变更
  #####################################
  info "Creating commit for version bump..."
  git add pubspec.yaml
  git commit -m "Version $NEW_VERSION_FULL"
  git push origin main
  success "Successfully pushed commit 'Version $NEW_VERSION_FULL' to remote!"
else
  NEW_VERSION_FULL="$CURRENT_TAG"
fi

#####################################
# 4. 执行 La Totale 清理
#####################################
info "Starting La Totale..."
./scripts/la-totale.sh
success "La Totale finished successfully."

#####################################
# 5. 创建并推送 Git tag（触发 CI 构建）
#####################################
info "Creating tag '$NEW_VERSION_FULL'..."
git tag -a "$NEW_VERSION_FULL" -m "Release $NEW_VERSION_FULL"
git push origin "$NEW_VERSION_FULL"

success "Successfully pushed tag '$NEW_VERSION_FULL' to remote!"
success "Release process completed. CI will handle the build and upload."
