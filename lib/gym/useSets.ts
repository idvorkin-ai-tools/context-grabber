/**
 * Re-export of igor-timer's useSets hook.
 * Uses our SQLite-backed setsStorage instead of IndexedDB.
 */
import { useCallback, useEffect, useState } from "react";
import { clearSetsCount, loadSetsCount, saveSetsCount } from "./setsStorage";

export interface SetsState {
  count: number;
  maxCount: number;
  isLoaded: boolean;
}

export function useSets(maxCount = 15) {
  const [count, setCount] = useState(0);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    loadSetsCount()
      .then(savedCount => setCount(Math.min(savedCount, maxCount)))
      .catch(() => {})
      .finally(() => setIsLoaded(true));
  }, [maxCount]);

  useEffect(() => {
    if (isLoaded) saveSetsCount(count);
  }, [count, isLoaded]);

  const increment = useCallback(() => {
    setCount(prev => Math.min(prev + 1, maxCount));
  }, [maxCount]);

  const undo = useCallback(() => {
    setCount(prev => Math.max(prev - 1, 0));
  }, []);

  const reset = useCallback(() => {
    setCount(0);
    clearSetsCount();
  }, []);

  return { state: { count, maxCount, isLoaded }, increment, undo, reset };
}
