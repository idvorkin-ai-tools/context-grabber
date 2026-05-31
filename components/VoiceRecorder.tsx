import React, {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import { Text, TouchableOpacity, View } from "react-native";
import {
  RecordingPresets,
  useAudioRecorder,
  useAudioRecorderState,
  requestRecordingPermissionsAsync,
  setAudioModeAsync,
} from "expo-audio";
import * as FileSystem from "expo-file-system/legacy";
import { uuidV4 } from "../lib/uuid";
import { ensureVoiceDir, voiceFilePath } from "../lib/voiceFiles";

export type RecordedVoice = {
  recordingId: string;
  filePath: string;
  durationMs: number;
};

export type VoiceRecorderHandle = {
  /**
   * If a recording is in progress, stop + finalize it and return the clip;
   * otherwise resolve null. Lets the parent's Save action capture an
   * in-progress recording instead of requiring a separate stop tap.
   */
  flush: () => Promise<RecordedVoice | null>;
  /**
   * Start a fresh recording. No-op if one is already in progress. Lets the
   * parent continue a recording streak across "Save & add another".
   */
  start: () => Promise<void>;
};

type Props = {
  onRecorded: (voice: RecordedVoice) => void;
  onError?: (msg: string) => void;
  /** Auto-start recording when the recorder mounts (mobile-default UX). */
  autoStart?: boolean;
  disabled?: boolean;
  /**
   * Compact circular mic button (for placing in a button row) instead of
   * the full-width pill. Same tap-to-toggle behavior; red while recording.
   */
  compact?: boolean;
};

/**
 * Tap-to-toggle voice recorder. Records to documents/voice/<uuid>.m4a
 * using HIGH_QUALITY preset (M4A AAC, ~16kHz on iPhone). On stop it
 * computes the duration and hands the path back to the parent via
 * onRecorded — caller is responsible for inserting the AudioRecording
 * row + pairing it with the journal entry.
 */
export const VoiceRecorder = forwardRef<VoiceRecorderHandle, Props>(
  function VoiceRecorder({ onRecorded, onError, autoStart, disabled, compact }, ref) {
  const recorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
  const state = useAudioRecorderState(recorder, 250);
  const [permissionAsked, setPermissionAsked] = useState(false);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const startTimeRef = useRef<number | null>(null);

  useEffect(() => {
    if (autoStart && !permissionAsked && !state.isRecording) {
      void start();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoStart]);

  // Recreated each render so it always closes over the latest recording
  // state + stop(); Save calls this to finalize an in-progress clip.
  useImperativeHandle(ref, () => ({
    flush: async () => (state.isRecording ? await stop() : null),
    start: async () => {
      if (!state.isRecording) await start();
    },
  }));

  async function start() {
    try {
      if (!permissionAsked) {
        const perm = await requestRecordingPermissionsAsync();
        setPermissionAsked(true);
        if (!perm.granted) {
          onError?.("microphone permission denied");
          return;
        }
      }
      // expo-audio refuses to record unless the iOS audio session is
      // explicitly switched into a recording-capable category. Default
      // is playback-only; we have to flip allowsRecording before the
      // first recorder.record() of the session.
      await setAudioModeAsync({
        allowsRecording: true,
        playsInSilentMode: true,
      });
      await ensureVoiceDir();
      const id = uuidV4();
      const path = voiceFilePath(id);
      setPendingId(id);
      startTimeRef.current = Date.now();
      // expo-audio's documented flow: prepare → record. Without
      // prepareToRecordAsync the recorder silently no-ops on iOS,
      // which manifests as "tap does nothing" with no error.
      await recorder.prepareToRecordAsync();
      recorder.record();
      // Stash the target path on the recorder via closure — used in stop().
      (recorder as any).__targetPath = path;
    } catch (e: any) {
      onError?.(e?.message ?? String(e));
    }
  }

  async function stop(): Promise<RecordedVoice | null> {
    try {
      await recorder.stop();
      const sourceUri = recorder.uri;
      const id = pendingId;
      const targetPath = (recorder as any).__targetPath as string | undefined;
      const elapsed = startTimeRef.current
        ? Date.now() - startTimeRef.current
        : 0;
      if (!sourceUri || !id || !targetPath) {
        onError?.("recording produced no file");
        return null;
      }
      // Move the recorder's temp file into our voice/ dir.
      await FileSystem.moveAsync({ from: sourceUri, to: targetPath });
      const voice: RecordedVoice = {
        recordingId: id,
        filePath: targetPath,
        durationMs: elapsed,
      };
      onRecorded(voice);
      setPendingId(null);
      startTimeRef.current = null;
      return voice;
    } catch (e: any) {
      onError?.(e?.message ?? String(e));
      return null;
    }
  }

  const recording = state.isRecording;
  const elapsedSec = state.durationMillis
    ? Math.floor(state.durationMillis / 1000)
    : startTimeRef.current
      ? Math.floor((Date.now() - startTimeRef.current) / 1000)
      : 0;

  if (compact) {
    return (
      <TouchableOpacity
        onPress={recording ? stop : start}
        disabled={disabled}
        testID="voice-record-toggle"
        accessibilityLabel={recording ? "Stop recording" : "Record voice"}
        style={{
          width: 52,
          height: 52,
          borderRadius: 26,
          backgroundColor: recording ? "#d44" : "#1a1a1a",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Text style={{ fontSize: recording ? 18 : 22 }}>
          {recording ? "■" : "🎤"}
        </Text>
      </TouchableOpacity>
    );
  }

  return (
    <View style={{ alignItems: "center" }}>
      <TouchableOpacity
        onPress={recording ? stop : start}
        disabled={disabled}
        testID="voice-record-toggle"
        accessibilityLabel={recording ? "Stop recording" : "Record voice"}
        style={{
          backgroundColor: recording ? "#d44" : "#2a2a2a",
          paddingVertical: 14,
          paddingHorizontal: 24,
          borderRadius: 32,
          minWidth: 160,
          alignItems: "center",
        }}
      >
        <Text style={{ color: "#fff", fontSize: 16, fontWeight: "600" }}>
          {recording ? `■  ${formatTime(elapsedSec)}` : "●  Record"}
        </Text>
      </TouchableOpacity>
      {recording && (
        <Text style={{ color: "#888", fontSize: 11, marginTop: 6 }}>
          tap to stop and save
        </Text>
      )}
    </View>
  );
});

function formatTime(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}
