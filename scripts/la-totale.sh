#!/bin/bash

# ANSI color codes
GREEN="\033[1;32m"
LIGHT_BLUE="\033[1;34m"
RED="\033[1;31m"
NC="\033[0m"  # No Color

# Log functions with colors
success() {
  echo -e "\n${GREEN}[LA TOTALE] $1${NC}"
}
info() {
  echo -e "\n${LIGHT_BLUE}[LA TOTALE] $1${NC}"
}
error() {
  echo -e "\n${RED}[LA TOTALE] $1${NC}"
}

# Check if pubspec.yaml exists in the current directory
if [ ! -f "pubspec.yaml" ]; then
  error "pubspec.yaml not found. Please run this script from the root mobile folder."
  exit 1
fi

# Array of commands
commands=(
  "rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/ephemeral ios/Runner.xcworkspace/xcshareddata/swiftpm ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
  "flutter clean"
  "dart run build_runner clean"
  "find . -name '*.g.dart' -delete"
  "find . -name '*.freezed.dart' -delete"
  "find . -name 'app_localizations*.dart' -delete"
  "rm -rf android/app/.cxx"
  "flutter pub get"
  "dart run build_runner build --delete-conflicting-outputs"
  "flutter gen-l10n"
  "dart run flutter_launcher_icons"
  "flutter test"
  "flutter build ios --config-only"
)

# Start of the script
info "Starting La Totale..."

# Loop through each command
for command in "${commands[@]}"; do
  # Log the description dynamically using the command
  info "Running '$command'..."

  # Run the command
  bash -c "$command"
  if [ $? -ne 0 ]; then
    error "'$command' failed."
    exit 1
  fi
done

# End of the script
success "Completed successfully."
