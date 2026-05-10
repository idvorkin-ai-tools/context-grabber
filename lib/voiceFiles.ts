// Voice-note file management. Audio recordings live as .m4a files
// under documents/voice/<recordingId>.m4a. Both the local recorder and
// the CloudKit-asset downloader land files at the same path so callers
// can always look up by recording id.

import * as FileSystem from "expo-file-system/legacy";

const VOICE_DIR = `${FileSystem.documentDirectory}voice/`;

export function voiceFilePath(recordingId: string): string {
  return `${VOICE_DIR}${recordingId}.m4a`;
}

export async function ensureVoiceDir(): Promise<void> {
  const info = await FileSystem.getInfoAsync(VOICE_DIR);
  if (!info.exists) {
    await FileSystem.makeDirectoryAsync(VOICE_DIR, { intermediates: true });
  }
}

export async function deleteVoiceFile(recordingId: string): Promise<void> {
  const path = voiceFilePath(recordingId);
  const info = await FileSystem.getInfoAsync(path);
  if (info.exists) {
    await FileSystem.deleteAsync(path, { idempotent: true });
  }
}

export async function voiceFileExists(recordingId: string): Promise<boolean> {
  const info = await FileSystem.getInfoAsync(voiceFilePath(recordingId));
  return info.exists;
}
