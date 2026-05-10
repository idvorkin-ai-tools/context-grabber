import React, { useEffect, useState } from "react";
import { Text, TouchableOpacity, View, ActivityIndicator } from "react-native";
import { useAudioPlayer, useAudioPlayerStatus } from "expo-audio";
import * as SQLite from "expo-sqlite";
import { ensureAudioLocal } from "../lib/cloudkit";
import { voiceFileExists, voiceFilePath } from "../lib/voiceFiles";

type Props = {
  recordingId: string;
  durationMs: number;
  db: SQLite.SQLiteDatabase | null;
};

/**
 * Inline play button for a journal entry's voice note. On first tap,
 * makes sure the file is on disk (downloads from CloudKit if not),
 * then plays. Subsequent taps just toggle play/pause.
 */
export function AudioPlayer({ recordingId, durationMs, db }: Props) {
  const [localPath, setLocalPath] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Probe disk on mount — if the file's already cached we can show
  // the play affordance immediately.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const exists = await voiceFileExists(recordingId);
      if (!cancelled && exists) setLocalPath(voiceFilePath(recordingId));
    })();
    return () => {
      cancelled = true;
    };
  }, [recordingId]);

  const player = useAudioPlayer(
    localPath ? { uri: localPath } : null,
  );
  const status = useAudioPlayerStatus(player);

  async function ensureDownloaded(): Promise<string | null> {
    if (localPath) return localPath;
    if (!db) {
      setError("DB not ready");
      return null;
    }
    setDownloading(true);
    try {
      const path = await ensureAudioLocal(db, recordingId);
      setLocalPath(path);
      return path;
    } catch (e: any) {
      setError(e?.message ?? String(e));
      return null;
    } finally {
      setDownloading(false);
    }
  }

  async function handleTap() {
    const path = await ensureDownloaded();
    if (!path) return;
    if (status.playing) {
      player.pause();
    } else {
      // Restart from beginning if we'd hit the end.
      if (
        status.currentTime &&
        status.duration &&
        status.currentTime >= status.duration - 0.1
      ) {
        player.seekTo(0);
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
