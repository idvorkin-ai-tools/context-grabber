// Inline HR sparkline for one set, rendered with React Native Views (no
// external chart library, no SVG). Shows three phases of a workout set —
// the spike, the recovery curve, and the flat "idle" tail — by plotting
// the raw HR trace from set start through the rest gap to the next set.
//
// Visual cues:
//   - Green dot at the peak HR
//   - Blue dot at the recovery floor (lowest HR after peak)
//   - Faint vertical line at the set's elevated-window end (where HR has
//     descended SET_DESCENT_BPM below peak)
//
// Used inline next to each set row in the Workout Analysis screen.

import React from "react";
import { View, StyleSheet } from "react-native";

type Point = { tSec: number; bpm: number };

type Props = {
  /** HR trace for this set (set.trace from the analysis). tSec is seconds
   *  from set start. */
  trace: Point[];
  /** Width of the sparkline, in pixels. Height matches the row. */
  width: number;
  /** Height of the sparkline. Should match the surrounding row height. */
  height: number;
  /** Index in trace of the peak sample (so we can mark it). */
  peakIdx?: number;
  /** Index in trace of the recovery floor sample. */
  floorIdx?: number;
  /** Trace index where the set's elevated window ends (HR drops below
   *  descent threshold). Used for the faint vertical separator. */
  setEndIdx?: number;
};

const STROKE_COLOR = "#7a8595";
const STROKE_WIDTH = 1.5;
const PEAK_COLOR = "#4ade80";
const FLOOR_COLOR = "#3b82f6";
const DOT_SIZE = 4;
const SEPARATOR_COLOR = "rgba(255,255,255,0.08)";

export default function RecoverySparkline({
  trace,
  width,
  height,
  peakIdx,
  floorIdx,
  setEndIdx,
}: Props): React.JSX.Element | null {
  if (trace.length < 2) return null;

  const tMin = trace[0].tSec;
  const tMax = trace[trace.length - 1].tSec;
  const tRange = Math.max(1, tMax - tMin);
  const bpms = trace.map((p) => p.bpm);
  const bpmMin = Math.min(...bpms);
  const bpmMax = Math.max(...bpms);
  const bpmRange = Math.max(1, bpmMax - bpmMin);

  // Project a trace point to (x, y) inside the box.
  const project = (p: Point) => ({
    x: ((p.tSec - tMin) / tRange) * width,
    // Invert y: high HR at top.
    y: height - ((p.bpm - bpmMin) / bpmRange) * height,
  });

  // Build segments — one View per pair of adjacent points, rotated/sized
  // to span between them. Avoids needing SVG / a chart library.
  const segments: React.JSX.Element[] = [];
  for (let i = 0; i < trace.length - 1; i++) {
    const a = project(trace[i]);
    const b = project(trace[i + 1]);
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len < 0.5) continue;
    const angleRad = Math.atan2(dy, dx);
    segments.push(
      <View
        key={i}
        style={{
          position: "absolute",
          left: a.x,
          top: a.y - STROKE_WIDTH / 2,
          width: len,
          height: STROKE_WIDTH,
          backgroundColor: STROKE_COLOR,
          transform: [
            { translateX: 0 },
            { translateY: 0 },
            { rotate: `${angleRad}rad` },
          ],
          transformOrigin: "0% 50%",
        }}
      />,
    );
  }

  // Vertical separator at end-of-set (where the HR dropped below the
  // working threshold). Shows where "spike+recovery" ends and "idle" begins.
  let separator: React.JSX.Element | null = null;
  if (setEndIdx != null && setEndIdx > 0 && setEndIdx < trace.length) {
    const sx = ((trace[setEndIdx].tSec - tMin) / tRange) * width;
    separator = (
      <View
        style={[
          styles.separator,
          { left: sx, height, backgroundColor: SEPARATOR_COLOR },
        ]}
      />
    );
  }

  // Peak / floor markers.
  const dot = (idx: number | undefined, color: string) => {
    if (idx == null || idx < 0 || idx >= trace.length) return null;
    const { x, y } = project(trace[idx]);
    return (
      <View
        style={[
          styles.dot,
          {
            left: x - DOT_SIZE / 2,
            top: y - DOT_SIZE / 2,
            backgroundColor: color,
          },
        ]}
      />
    );
  };

  return (
    <View style={[styles.container, { width, height }]}>
      {separator}
      {segments}
      {dot(peakIdx, PEAK_COLOR)}
      {dot(floorIdx, FLOOR_COLOR)}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: "relative",
  },
  separator: {
    position: "absolute",
    width: 1,
    top: 0,
  },
  dot: {
    position: "absolute",
    width: DOT_SIZE,
    height: DOT_SIZE,
    borderRadius: DOT_SIZE / 2,
  },
});
