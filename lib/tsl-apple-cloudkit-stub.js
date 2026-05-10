// Stub for tsl-apple-cloudkit on native platforms.
// expo-cloudkit's web loader (cloudkit-loader.js) lazy-imports
// tsl-apple-cloudkit, which depends on Node's `crypto` and `fs` — neither
// exists in React Native. The dynamic import is never executed on iOS at
// runtime (we use the native CloudKit framework instead), but Metro
// statically discovers it and chokes. Aliasing to this stub keeps the
// bundler happy while leaving the native path untouched.
module.exports = {
  default: () => {
    throw new Error(
      "tsl-apple-cloudkit is web-only; native iOS uses the CloudKit framework via expo-cloudkit's native module.",
    );
  },
};
