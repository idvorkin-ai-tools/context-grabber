const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const config = getDefaultConfig(__dirname);

// Watch the igor-timer submodule for changes during development
const igorTimerSrc = path.resolve(__dirname, "vendor/igor-timer/src");
config.watchFolders = [igorTimerSrc];

// expo-cloudkit's web loader pulls in tsl-apple-cloudkit, a Node-flavored
// library that requires `crypto` + `fs`. On native iOS we never execute that
// path (we go through the native CloudKit framework), but Metro still tries
// to resolve the import. Redirect it to a stub.
const tslStub = path.resolve(__dirname, "lib/tsl-apple-cloudkit-stub.js");
const baseResolveRequest = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (
    (platform === "ios" || platform === "android") &&
    moduleName === "tsl-apple-cloudkit"
  ) {
    return { type: "sourceFile", filePath: tslStub };
  }
  if (baseResolveRequest) {
    return baseResolveRequest(context, moduleName, platform);
  }
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
