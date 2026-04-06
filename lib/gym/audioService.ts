/**
 * Shim for igor-timer's audioService.
 * On React Native, expo-av handles audio context automatically,
 * so ensureRunning() is a no-op.
 */
export const audioService = {
  ensureRunning(): void {
    // No-op on React Native — expo-av manages audio session
  },
};
