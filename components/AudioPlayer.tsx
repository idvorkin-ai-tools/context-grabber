import React, { useEffect, useRef, useState } from "react";
import { Text, TouchableOpacity, View, ActivityIndicator } from "react-native";
import {
  useAudioPlayer,
  useAudioPlayerStatus,
  setAudioModeAsync,
} from "expo-audio";
import * as SQLite from "expo-sqlite";
import { ensureAudioLocal } from "../lib/cloudkit";
import { voiceFileExists, voiceFilePath } from "../lib/voiceFiles";

type Props = {
  recordingId: string;
  durationMs: number;
  db: SQLite.SQLiteDatabase | null;
};

/**
 * Inline play button for a journal entry's voice note. The local file
 * path is known synchronously (always `documents/voice/<id>.m4a`); the
 * player is initialised against that path immediately. If the file
 * doesn't exist on disk yet (entry came from iPad sync), we lazily
 * download the CKAsset on first tap, then `replace()` the player's
 * source so it picks up the now-on-disk file.
 */
export function AudioPlayer({ recordingId, durationMs, db }: Props) {
  const localPath = voiceFilePath(recordingId);
  const player = useAudioPlayer({ uri: localPath });
  const status = useAudioPlayerStatus(player);
  const [downloading, setDownloading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const hasFileRef = useRef(false);
  const audioSessionPreppedRef = useRef(false);

  // Probe disk on mount so the play button doesn't have to wait on a
  // download for entries whose files are already cached locally.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const exists = await voiceFileExists(recordingId);
      if (!cancelled) hasFileRef.current = exists;
    })();
    return () => {
      cancelled = true;
    };
  }, [recordingId]);

  async function ensurePlaybackSession() {
    // After a recording session the iOS audio category is .playAndRecord
    // with allowsRecording=true; some devices route playback through the
    // earpiece or refuse to play through expo-audio's playback path in
    // that state. Flip the session to playback-friendly before the first
    // play of this player's lifetime.
    if (audioSessionPreppedRef.current) return;
    try {
      await setAudioModeAsync({
        allowsRecording: false,
        playsInSilentMode: true,
      });
      audioSessionPreppedRef.current = true;
    } catch (e) {
      // Not fatal — playback may still work. Log only.
      console.warn("[audio-player] setAudioModeAsync failed:", e);
    }
  }

  async function ensureDownloaded(): Promise<boolean> {
    if (hasFileRef.current) return true;
    if (!db) {
      setError("DB not ready");
      return false;
    }
    setDownloading(true);
    try {
      await ensureAudioLocal(db, recordingId);
      hasFileRef.current = true;
      // The file is now on disk at the same path we initialised the
      // player against. Force expo-audio to re-load by re-setting source.
      player.replace({ uri: localPath });
      return true;
    } catch (e: any) {
      setError(e?.message ?? String(e));
      return false;
    } finally {
      setDownloading(false);
    }
  }

  async function handleTap() {
    setError(null);
    await ensurePlaybackSession();
    const ok = await ensureDownloaded();
    if (!ok) return;
    if (status.playing) {
      player.pause();
    } else {
      if (
        status.currentTime &&
        status.duration &&
        status.currentTime >= status.duration - 0.1
      ) {
        await player.seekTo(0);
      }
      player.play();
    }
  }

  const label = error
    ? "⚠"
    : downloading
      ? null
      : status.playing
        ? "❚❚"
        : "▶";

  const seconds = Math.round(durationMs / 1000);

  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
      <TouchableOpacity
        onPress={handleTap}
        disabled={downloading}
        style={{
          width: 36,
          height: 36,
          borderRadius: 18,
          backgroundColor: error ? "#553" : "#2a2a2a",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        {downloading ? (
          <ActivityIndicator size="small" color="#fff" />
        ) : (
          <Text style={{ color: "#fff", fontSize: 14 }}>{label}</Text>
        )}
      </TouchableOpacity>
      <Text style={{ color: "#aaa", fontSize: 12, fontVariant: ["tabular-nums"] }}>
        {formatDuration(seconds)}
      </Text>
      {error && (
        <Text style={{ color: "#ff8a8a", fontSize: 11 }} selectable>
          {error}
        </Text>
      )}
    </View>
  );
}

function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0:00";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}
