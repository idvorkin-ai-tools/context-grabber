import React, { useEffect, useRef, useState } from "react";
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

type Props = {
  onRecorded: (voice: RecordedVoice) => void;
  onError?: (msg: string) => void;
  /** Auto-start recording when the recorder mounts (mobile-default UX). */
  autoStart?: boolean;
  disabled?: boolean;
};

/**
 * Tap-to-toggle voice recorder. Records to documents/voice/<uuid>.m4a
 * using HIGH_QUALITY preset (M4A AAC, ~16kHz on iPhone). On stop it
 * computes the duration and hands the path back to the parent via
 * onRecorded — caller is responsible for inserting the AudioRecording
 * row + pairing it with the journal entry.
 */
export function VoiceRecorder({ onRecorded, onError, autoStart, disabled }: Props) {
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
      // expo-audio writes to its own internal path; we move on stop.
      recorder.record();
      // Stash the target path on the recorder via closure — used in stop().
      (recorder as any).__targetPath = path;
    } catch (e: any) {
      onError?.(e?.message ?? String(e));
    }
  }

  async function stop() {
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
        return;
      }
      // Move the recorder's temp file into our voice/ dir.
      await FileSystem.moveAsync({ from: sourceUri, to: targetPath });
      onRecorded({
        recordingId: id,
        filePath: targetPath,
        durationMs: elapsed,
      });
      setPendingId(null);
      startTimeRef.current = null;
    } catch (e: any) {
      onError?.(e?.message ?? String(e));
    }
  }

  const recording = state.isRecording;
  const elapsedSec = state.durationMillis
    ? Math.floor(state.durationMillis / 1000)
    : startTimeRef.current
      ? Math.floor((Date.now() - startTimeRef.current) / 1000)
      : 0;

  return (
    <View style={{ alignItems: "center" }}>
      <TouchableOpacity
        onPress={recording ? stop : start}
        disabled={disabled}
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
}

function formatTime(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}
