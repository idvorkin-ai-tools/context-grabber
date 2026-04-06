/**
 * Re-export of igor-timer's useStopwatch hook.
 * Copied for tsc — identical to vendor/igor-timer/src/hooks/useStopwatch.ts
 * with window.setInterval → setInterval for React Native compatibility.
 */
import { useCallback, useEffect, useRef, useState } from "react";

export interface StopwatchState {
  isRunning: boolean;
  elapsedMs: number;
  laps: number[];
}

export function useStopwatch() {
  const [state, setState] = useState<StopwatchState>({
    isRunning: false,
    elapsedMs: 0,
    laps: [],
  });

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startTimeRef = useRef<number>(0);
  const elapsedRef = useRef<number>(0);

  const clearTimer = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const start = useCallback(() => {
    startTimeRef.current = Date.now() - elapsedRef.current;
    setState(prev => ({ ...prev, isRunning: true }));
    intervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTimeRef.current;
      elapsedRef.current = elapsed;
      setState(prev => ({ ...prev, elapsedMs: elapsed }));
    }, 10);
  }, []);

  const pause = useCallback(() => {
    clearTimer();
    setState(prev => ({ ...prev, isRunning: false, elapsedMs: elapsedRef.current }));
  }, [clearTimer]);

  const toggle = useCallback(() => {
    if (state.isRunning) pause(); else start();
  }, [state.isRunning, start, pause]);

  const reset = useCallback(() => {
    clearTimer();
    elapsedRef.current = 0;
    setState({ isRunning: false, elapsedMs: 0, laps: [] });
  }, [clearTimer]);

  const lap = useCallback(() => {
    if (state.isRunning) {
      setState(prev => ({ ...prev, laps: [prev.elapsedMs, ...prev.laps] }));
    }
  }, [state.isRunning]);

  useEffect(() => () => clearTimer(), [clearTimer]);

  return { state, start, pause, toggle, reset, lap };
}

export function formatStopwatchTime(ms: number): { main: string; fraction: string } {
  const totalSecs = Math.floor(ms / 1000);
  const mins = Math.floor(totalSecs / 60);
  const secs = totalSecs % 60;
  const centis = Math.floor((ms % 1000) / 10);
  return {
    main: `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`,
    fraction: `.${centis.toString().padStart(2, "0")}`,
  };
}
