import React, { useState } from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import * as Clipboard from "expo-clipboard";
import type { ContextSnapshot } from "../lib/appTypes";

type Props = {
  snapshot: ContextSnapshot | null;
};

function formatAge(latestMs: number | null): string {
  if (latestMs == null) return "—";
  const ageMs = Date.now() - latestMs;
  if (ageMs < 5 * 60 * 1000) return "now";
  if (ageMs < 60 * 60 * 1000) return `${Math.round(ageMs / 60000)} min ago`;
  if (ageMs < 24 * 60 * 60 * 1000) return `${Math.round(ageMs / 3600000)} hr ago`;
  const days = Math.round(ageMs / (24 * 3600000));
  return days === 1 ? "yesterday" : `${days} days ago`;
}

export function CurrentLocationCard({ snapshot }: Props) {
  const [copyState, setCopyState] = useState<"idle" | "copied">("idle");
  const location = snapshot?.location ?? null;

  const latestMs =
    location?.timestamp ??
    (snapshot?.locationHistory && snapshot.locationHistory.length > 0
      ? snapshot.locationHistory[snapshot.locationHistory.length - 1].timestamp
      : null);

  async function handleCopy() {
    if (!location) return;
    const text = `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`;
    await Clipboard.setStringAsync(text);
    setCopyState("copied");
    setTimeout(() => setCopyState("idle"), 1500);
  }

  return (
    <View style={styles.card} testID="current-location-card">
      <View style={styles.textCol}>
        <Text style={styles.label}>Current</Text>
        {location ? (
          <Text style={styles.value}>
            {location.latitude.toFixed(4)}, {location.longitude.toFixed(4)}
          </Text>
        ) : (
          <Text style={[styles.value, styles.faint]}>Unavailable</Text>
        )}
        <Text style={styles.sub}>{formatAge(latestMs)}</Text>
      </View>
      {location && (
        <TouchableOpacity
          onPress={handleCopy}
          style={styles.copyBtn}
          testID="current-location-copy"
          accessibilityLabel="Copy current coordinates"
        >
          <Text style={styles.copyText}>
            {copyState === "copied" ? "✓ Copied" : "Copy"}
          </Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 12,
  },
  textCol: { flex: 1 },
  label: { color: "#888", fontSize: 12, marginBottom: 6 },
  value: {
    color: "#e0e0e0",
    fontSize: 18,
    fontWeight: "600",
    fontVariant: ["tabular-nums"],
  },
  faint: { color: "#555" },
  sub: { color: "#888", fontSize: 12, marginTop: 4 },
  copyBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: "rgba(76, 201, 240, 0.18)",
    marginLeft: 12,
  },
  copyText: { color: "#4cc9f0", fontSize: 13, fontWeight: "600" },
});
