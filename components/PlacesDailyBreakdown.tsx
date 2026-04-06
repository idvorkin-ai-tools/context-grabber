import React, { useMemo, useState } from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import type { PlaceDaySummary } from "../lib/places_summary";

const COLORS = [
  "#4361ee", "#f72585", "#4cc9f0", "#7209b7", "#3a86a7",
  "#f77f00", "#06d6a0", "#e63946", "#a8dadc", "#fca311",
];

type Props = {
  days: PlaceDaySummary[];
};

function formatHours(minutes: number): string {
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const h = Math.round(minutes / 6) / 10;
  return `${h}h`;
}

function formatDateLabel(dateKey: string): string {
  const [y, m, d] = dateKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${days[date.getDay()]} ${months[date.getMonth()]} ${date.getDate()}`;
}

function formatTime(ts: number): string {
  const d = new Date(ts);
  let h = d.getHours();
  const m = d.getMinutes();
  const period = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  return m === 0 ? `${h}${period}` : `${h}:${String(m).padStart(2, "0")}${period}`;
}

export default function PlacesDailyBreakdown({ days }: Props) {
  const [expandedDay, setExpandedDay] = useState<string | null>(null);

  const colorMap = useMemo(() => {
    const map = new Map<string, string>();
    const allPlaces = new Set<string>();
    for (const day of days) {
      for (const p of day.places) allPlaces.add(p.placeId);
    }
    let i = 0;
    for (const id of allPlaces) {
      map.set(id, COLORS[i % COLORS.length]);
      i++;
    }
    return map;
  }, [days]);

  if (days.length === 0) return null;

  return (
    <View style={styles.container}>
      {days.map((day) => {
        const maxMinutes = day.places.length > 0 ? day.places[0].totalMinutes : 1;
        const isExpanded = expandedDay === day.dateKey;
        return (
          <TouchableOpacity
            key={day.dateKey}
            style={styles.card}
            activeOpacity={0.7}
            onPress={() => setExpandedDay(isExpanded ? null : day.dateKey)}
          >
            <View style={styles.dateRow}>
              <Text style={styles.dateHeader}>{formatDateLabel(day.dateKey)}</Text>
              <Text style={styles.totalText}>{formatHours(day.totalTrackedMinutes)}</Text>
            </View>
            {day.places.map((place) => {
              const fraction = maxMinutes > 0 ? place.totalMinutes / maxMinutes : 0;
              const color = colorMap.get(place.placeId) ?? COLORS[0];
              return (
                <View key={place.placeId} style={styles.row}>
                  <View style={styles.barContainer}>
                    <View style={[styles.bar, { width: `${Math.max(fraction * 100, 2)}%`, backgroundColor: color }]} />
                  </View>
                  <Text style={styles.placeName} numberOfLines={1}>{place.placeId}</Text>
                  <Text style={styles.hours}>{formatHours(place.totalMinutes)}</Text>
                </View>
              );
            })}

            {/* Expanded: individual visits */}
            {isExpanded && day.visits.length > 0 && (
              <View style={styles.visitsSection}>
                {day.visits.map((v, i) => {
                  const color = colorMap.get(v.placeId) ?? COLORS[0];
                  return (
                    <View key={i} style={styles.visitRow}>
                      <View style={[styles.visitDot, { backgroundColor: color }]} />
                      <Text style={styles.visitTime}>
                        {formatTime(v.startTime)}–{formatTime(v.endTime)}
                      </Text>
                      <Text style={styles.visitPlace} numberOfLines={1}>{v.placeId}</Text>
                      <Text style={styles.visitDuration}>{formatHours(v.durationMinutes)}</Text>
                    </View>
                  );
                })}
              </View>
            )}
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { marginTop: 12, gap: 8 },
  card: {
    backgroundColor: "#16213e",
    borderRadius: 10,
    padding: 12,
  },
  dateRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  dateHeader: {
    fontSize: 14,
    fontWeight: "700",
    color: "#4cc9f0",
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 5,
  },
  barContainer: {
    flex: 1,
    height: 14,
    backgroundColor: "#1a1a2e",
    borderRadius: 4,
    overflow: "hidden",
  },
  bar: {
    height: "100%",
    borderRadius: 4,
  },
  placeName: {
    color: "#e0e0e0",
    fontSize: 12,
    fontWeight: "500",
    width: 80,
    marginLeft: 8,
    textAlign: "left",
  },
  hours: {
    color: "#aaa",
    fontSize: 12,
    width: 36,
    textAlign: "right",
  },
  totalText: {
    color: "#888",
    fontSize: 12,
  },
  visitsSection: {
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: "#1a1a2e",
  },
  visitRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 3,
  },
  visitDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 6,
  },
  visitTime: {
    color: "#888",
    fontSize: 11,
    width: 90,
  },
  visitPlace: {
    color: "#e0e0e0",
    fontSize: 12,
    flex: 1,
  },
  visitDuration: {
    color: "#666",
    fontSize: 11,
    width: 32,
    textAlign: "right",
  },
});
