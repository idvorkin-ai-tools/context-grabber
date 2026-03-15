# Context Grabber task runner

# Generate version info from git
generate-version:
    node scripts/generate-version.js

# Deploy OTA update to production channel (used by `just deploy` builds)
ota message="OTA update": generate-version
    CI=1 npx eas-cli update --branch production --message "{{message}}" --environment production

# Run tests
test:
    npx jest

# Build release and deploy to physical iPhone (supports OTA updates)
deploy device="Igor iPhone 17": generate-version
    npx expo run:ios --device "{{device}}" --configuration Release

# Build debug for development (connects to Metro dev server, no OTA)
build device="Igor iPhone 17": generate-version
    npx expo run:ios --device "{{device}}"

# Start Metro dev server
dev: generate-version
    npx expo start --dev-client

# Install dependencies and pods
setup:
    npm install
    npx expo prebuild --platform ios
    cd ios && pod install
