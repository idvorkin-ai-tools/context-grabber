/**
 * React Native audio hook for gym timer sounds.
 * Same interface as igor-timer's useAudio, backed by expo-av.
 */
import { useCallback, useEffect, useRef } from "react";
import { Audio } from "expo-av";

function createToneUri(frequency: number, durationMs: number): string {
  // expo-av can't generate tones directly — we use a short silent sound
  // and rely on Haptics as primary feedback. For real tones, we'd need
  // pre-recorded audio files or a native module.
  // For now, this is a placeholder that will be replaced with actual tone files.
  return "";
}

/**
 * Attempt to play a beep using expo-av.
 * Falls back silently if audio isn't available.
 */
async function playTone(frequency: number, durationSec: number, volume: number): Promise<void> {
  try {
    const { sound } = await Audio.Sound.createAsync(
      require("../../assets/beep.wav"),
      { volume, shouldPlay: true }
    );
    // Auto-unload after playback
    sound.setOnPlaybackStatusUpdate((status) => {
      if ("didJustFinish" in status && status.didJustFinish) {
        sound.unloadAsync();
      }
    });
  } catch {
    // Audio not available — fail silently
  }
}

export function useAudio() {
  useEffect(() => {
    Audio.setAudioModeAsync({
      playsInSilentModeIOS: true,
      staysActiveInBackground: true,
    });
  }, []);

  const playBeep = useCallback(
    (frequency = 880, duration = 0.15, _type = "sine", volume = 0.7) => {
      playTone(frequency, duration, volume);
    },
    [],
  );

  const playStartBeep = useCallback(() => {
    playBeep(800, 0.15, "sine", 0.8);
    setTimeout(() => playBeep(1000, 0.15, "sine", 0.8), 100);
    setTimeout(() => playBeep(1200, 0.25, "sine", 0.9), 200);
  }, [playBeep]);

  const playEndBeep = useCallback(() => {
    playBeep(800, 0.2, "sine", 0.7);
    setTimeout(() => playBeep(600, 0.3, "sine", 0.7), 200);
  }, [playBeep]);

  const playCountdownBeep = useCallback(
    () => playBeep(660, 0.08, "sine", 0.6),
    [playBeep],
  );

  const playFinishBeep = useCallback(() => {
    playBeep(523, 0.2, "sine", 0.8);
    setTimeout(() => playBeep(659, 0.2, "sine", 0.8), 150);
    setTimeout(() => playBeep(784, 0.2, "sine", 0.8), 300);
    setTimeout(() => playBeep(1047, 0.4, "sine", 0.9), 450);
  }, [playBeep]);

  return { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep };
}
