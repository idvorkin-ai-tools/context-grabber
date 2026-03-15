# Context Grabber task runner

# Deploy OTA update to production
ota message="OTA update":
    CI=1 npx eas-cli update --branch production --message "{{message}}" --environment production

# Run tests
test:
    npx jest

# Build and deploy to physical iPhone
build device="Igor iPhone 17":
    npx expo run:ios --device "{{device}}"

# Start Metro dev server
dev:
    npx expo start --dev-client

# Install dependencies and pods
setup:
    npm install
    npx expo prebuild --platform ios
    cd ios && pod install
