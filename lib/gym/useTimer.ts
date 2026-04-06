/**
 * Re-export of igor-timer's useTimer hook.
 * Types are defined here for tsc; Metro resolves the runtime implementation
 * from vendor/igor-timer/src/hooks/useTimer.ts via metro.config.js.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useAudio } from "./useAudio";
import { audioService } from "./audioService";

export type Phase = "idle" | "prep" | "work" | "rest" | "done";

export interface TimerProfile {
  name: string;
  workTime: number;
  restTime: number;
  rounds: number;
  cycles: number;
  prepTime: number;
}

export interface TimerState {
  isRunning: boolean;
  isPaused: boolean;
  phase: Phase;
  timeLeft: number;
  currentRound: number;
  totalRounds: number;
  totalElapsed: number;
}

const DEFAULT_STATE: TimerState = {
  isRunning: false,
  isPaused: false,
  phase: "idle",
  timeLeft: 0,
  currentRound: 1,
  totalRounds: 6,
  totalElapsed: 0,
};

export function useTimer(profile: TimerProfile) {
  const [state, setState] = useState<TimerState>({
    ...DEFAULT_STATE,
    totalRounds: profile.rounds,
  });

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const stateRef = useRef(state);
  const profileRef = useRef(profile);

  useEffect(() => { stateRef.current = state; });
  useEffect(() => { profileRef.current = profile; });

  const { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep } = useAudio();

  const calculateTotalTime = useCallback(() => {
    return ((profile.workTime + profile.restTime) * profile.rounds * profile.cycles) + profile.prepTime;
  }, [profile]);

  const clearTimer = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const reset = useCallback(() => {
    clearTimer();
    const newState = { ...DEFAULT_STATE, totalRounds: profileRef.current.rounds };
    stateRef.current = newState;
    setState(newState);
  }, [clearTimer]);

  const tick = useCallback(() => {
    const currentState = stateRef.current;
    const currentProfile = profileRef.current;
    if (!currentState.isRunning) return;

    const newTimeLeft = currentState.timeLeft - 1;
    if (newTimeLeft <= 3 && newTimeLeft > 0) playCountdownBeep();

    let newState: TimerState;
    if (newTimeLeft <= 0) {
      if (currentState.phase === "prep") {
        playStartBeep();
        newState = { ...currentState, phase: "work", timeLeft: currentProfile.workTime, totalElapsed: currentState.totalElapsed + 1 };
      } else if (currentState.phase === "work") {
        playEndBeep();
        if (currentState.currentRound >= currentProfile.rounds) {
          clearTimer();
          playFinishBeep();
          newState = { ...currentState, phase: "done", timeLeft: 0, isRunning: false, totalElapsed: currentState.totalElapsed + 1 };
        } else {
          newState = { ...currentState, phase: "rest", timeLeft: currentProfile.restTime, totalElapsed: currentState.totalElapsed + 1 };
        }
      } else if (currentState.phase === "rest") {
        playStartBeep();
        newState = { ...currentState, phase: "work", timeLeft: currentProfile.workTime, currentRound: currentState.currentRound + 1, totalElapsed: currentState.totalElapsed + 1 };
      } else {
        newState = currentState;
      }
    } else {
      newState = { ...currentState, timeLeft: newTimeLeft, totalElapsed: currentState.totalElapsed + 1 };
    }
    stateRef.current = newState;
    setState(newState);
  }, [playCountdownBeep, playStartBeep, playEndBeep, playFinishBeep, clearTimer]);

  const start = useCallback(() => {
    audioService.ensureRunning();
    const currentState = stateRef.current;
    let newState: TimerState;
    if (currentState.isPaused) {
      newState = { ...currentState, isRunning: true, isPaused: false };
    } else {
      playStartBeep();
      newState = {
        isRunning: true, isPaused: false, phase: "prep",
        timeLeft: profileRef.current.prepTime, currentRound: 1,
        totalRounds: profileRef.current.rounds, totalElapsed: 0,
      };
    }
    stateRef.current = newState;
    setState(newState);
    clearTimer();
    intervalRef.current = setInterval(tick, 1000);
  }, [playStartBeep, tick, clearTimer]);

  const pause = useCallback(() => {
    clearTimer();
    const newState = { ...stateRef.current, isRunning: false, isPaused: true };
    stateRef.current = newState;
    setState(newState);
  }, [clearTimer]);

  const toggle = useCallback(() => {
    if (stateRef.current.isRunning) pause(); else start();
  }, [start, pause]);

  useEffect(() => () => clearTimer(), [clearTimer]);

  useEffect(() => {
    if (!state.isRunning && !state.isPaused) {
      setState(prev => ({ ...prev, totalRounds: profile.rounds }));
    }
  }, [profile.rounds, state.isRunning, state.isPaused]);

  return { state, profile, start, pause, toggle, reset, calculateTotalTime };
}
