import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { type DailyValue, formatDateKey } from "../lib/weekly";

// ─── Constants ────────────────────────────────────────────────────────────────

const CHART_HEIGHT = 200;
const LABEL_HEIGHT = 30;
const BAR_RADIUS = 4;
const DASH_HEIGHT = 2;

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// ─── Props ────────────────────────────────────────────────────────────────────

type Props = {
  data: DailyValue[];
  color: string;
  unit: string;
};

// ─── BarChart ─────────────────────────────────────────────────────────────────

export default function BarChart({ data, color, unit }: Props): React.JSX.Element {
  const today = formatDateKey(new Date());

  // Compute the max value across the week (non-null only).
  const maxValue = data.reduce<number>((acc, d) => {
    if (d.value !== null && d.value > acc) return d.value;
    return acc;
  }, 0);

  // Dim color for non-today bars: append "4D" (30% opacity) to the hex string.
  const dimColor = `${color}4D`;

  return (
    <View style={styles.container}>
      {/* Bar area */}
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {data.map((day) => {
          const isToday = day.date === today;
          const barColor = isToday ? color : dimColor;

          // Determine the day-of-week label by parsing date as UTC midnight.
          const parsed = new Date(`${day.date}T00:00:00Z`);
          const dayLabel = DAY_LABELS[parsed.getUTCDay()];

          if (day.value === null) {
            // Null day: render a small dash centred at the bottom of the chart area.
            return (
              <View key={day.date} style={styles.barColumn}>
                <View style={styles.barWrapper}>
                  <View
                    style={[
                      styles.dash,
                      { backgroundColor: barColor },
                    ]}
                  />
                </View>
                <Text style={[styles.dayLabel, isToday && { color }]}>
                  {dayLabel}
                </Text>
              </View>
            );
          }

          // Height proportional to maxValue; guard against divide-by-zero.
          const heightFraction = maxValue > 0 ? day.value / maxValue : 0;
          const barHeight = Math.max(4, Math.round(heightFraction * CHART_HEIGHT));

          return (
            <View key={day.date} style={styles.barColumn}>
              <View style={styles.barWrapper}>
                <View
                  style={[
                    styles.bar,
                    {
                      height: barHeight,
                      backgroundColor: barColor,
                      borderRadius: BAR_RADIUS,
                    },
                  ]}
                />
              </View>
              <Text style={[styles.dayLabel, isToday && { color }]}>
                {dayLabel}
              </Text>
            </View>
          );
        })}
      </View>

      {/* Unit label */}
      <Text style={styles.unitLabel}>{unit}</Text>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    width: "100%",
  },
  chartArea: {
    flexDirection: "row",
    alignItems: "flex-end",
    paddingBottom: LABEL_HEIGHT,
  },
  barColumn: {
    flex: 1,
    alignItems: "center",
  },
  barWrapper: {
    flex: 1,
    justifyContent: "flex-end",
    alignItems: "center",
    width: "100%",
  },
  bar: {
    width: "60%",
  },
  dash: {
    width: "40%",
    height: DASH_HEIGHT,
    borderRadius: 1,
  },
  dayLabel: {
    position: "absolute",
    bottom: 0,
    fontSize: 11,
    color: "#888",
    textAlign: "center",
    height: LABEL_HEIGHT,
    lineHeight: LABEL_HEIGHT,
  },
  unitLabel: {
    fontSize: 11,
    color: "#888",
    textAlign: "center",
    marginTop: 4,
  },
});
