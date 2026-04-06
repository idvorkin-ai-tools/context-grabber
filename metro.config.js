const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const config = getDefaultConfig(__dirname);

// Watch the igor-timer submodule for changes during development
const igorTimerSrc = path.resolve(__dirname, "vendor/igor-timer/src");
config.watchFolders = [igorTimerSrc];

module.exports = config;
