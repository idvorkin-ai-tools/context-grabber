import React from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import {
  useAudioPlayer,
  useAudioPlayerStatus,
  setAudioModeAsync,
} from "expo-audio";

const SONG_TITLE = "How I want to live";
const SONG_SUB = "Pop version of the eulogy";

export function EulogySongCard() {
  const player = useAudioPlayer(require("../assets/audio/eulogy-song.mp3"));
  const status = useAudioPlayerStatus(player);

  async function handleToggle() {
    try {
      await setAudioModeAsync({
        allowsRecording: false,
        playsInSilentMode: true,
        // Keep the audio session live when the app backgrounds — without
        // this, expo-audio's default of `false` lets iOS pause the song
        // the moment the user switches apps. UIBackgroundModes already
        // declares "audio" in Info.plist.
        shouldPlayInBackground: true,
        // doNotMix is required for the lock-screen / control-center
        // playback controls to surface this app's now-playing.
        interruptionMode: "doNotMix",
      });
    } catch {
      // Not fatal — playback may still work.
    }
    if (status.playing) {
      player.pause();
      return;
    }
    if (
      status.currentTime &&
      status.duration &&
      status.currentTime >= status.duration - 0.1
    ) {
      await player.seekTo(0);
    }
    player.play();
  }

  const elapsed = formatDuration(status.currentTime);
  const total = formatDuration(status.duration);
  const progress =
    status.duration && status.duration > 0
      ? Math.min(1, (status.currentTime ?? 0) / status.duration)
      : 0;

  return (
    <View style={styles.card} testID="eulogy-song-card">
      <TouchableOpacity
        onPress={handleToggle}
        style={styles.button}
        testID="eulogy-song-toggle"
        accessibilityLabel={status.playing ? "Pause eulogy song" : "Play eulogy song"}
      >
        <Text style={styles.buttonGlyph}>{status.playing ? "❚❚" : "▶"}</Text>
      </TouchableOpacity>
      <View style={styles.meta}>
        <Text style={styles.title}>{SONG_TITLE}</Text>
        <Text style={styles.sub}>{SONG_SUB}</Text>
        <View style={styles.progressTrack}>
          <View style={[styles.progressFill, { width: `${progress * 100}%` }]} />
        </View>
        <Text style={styles.time}>
          {elapsed} / {total}
        </Text>
      </View>
    </View>
  );
}

function formatDuration(seconds: number | undefined | null): string {
  const s = Math.max(0, Math.round(seconds ?? 0));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${String(r).padStart(2, "0")}`;
}

const styles = StyleSheet.create({
  card: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#1f1a2e",
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: "rgba(246, 193, 119, 0.35)",
  },
  button: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: "#f6c177",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 12,
  },
  buttonGlyph: {
    color: "#1a1a2e",
    fontSize: 16,
    fontWeight: "700",
  },
  meta: { flex: 1 },
  title: {
    color: "#f6c177",
    fontSize: 14,
    fontWeight: "700",
    letterSpacing: 0.3,
  },
  sub: {
    color: "#bbb",
    fontSize: 11,
    marginTop: 2,
  },
  progressTrack: {
    marginTop: 8,
    height: 3,
    borderRadius: 2,
    backgroundColor: "rgba(255, 255, 255, 0.08)",
    overflow: "hidden",
  },
  progressFill: {
    height: "100%",
    backgroundColor: "#f6c177",
  },
  time: {
    color: "#888",
    fontSize: 10,
    marginTop: 3,
    fontVariant: ["tabular-nums"],
  },
});
