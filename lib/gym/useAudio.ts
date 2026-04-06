/**
 * React Native audio hook for gym timer sounds.
 * Same interface as igor-timer's useAudio, backed by expo-audio.
 */
import { useCallback, useEffect, useRef } from "react";
import { useAudioPlayer } from "expo-audio";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const beepAsset = require("../../assets/beep.wav");

export function useAudio() {
  const player = useAudioPlayer(beepAsset);

  const playBeep = useCallback(() => {
    try {
      player.seekTo(0);
      player.play();
    } catch {
      // Audio not available — fail silently
    }
  }, [player]);

  const playStartBeep = useCallback(() => {
    playBeep();
  }, [playBeep]);

  const playEndBeep = useCallback(() => {
    playBeep();
  }, [playBeep]);

  const playCountdownBeep = useCallback(() => {
    playBeep();
  }, [playBeep]);

  const playFinishBeep = useCallback(() => {
    playBeep();
    setTimeout(() => playBeep(), 200);
    setTimeout(() => playBeep(), 400);
  }, [playBeep]);

  return { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep };
}
