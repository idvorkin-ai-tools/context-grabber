/**
 * Sets persistence for React Native.
 * Drop-in replacement for igor-timer's IndexedDB setsStorage.
 * Uses our existing SQLite settings table.
 */
import { getSetting, setSetting } from "../db";
import type { SQLiteDatabase } from "expo-sqlite";

let _db: SQLiteDatabase | null = null;

export function setSetsDb(db: SQLiteDatabase) {
  _db = db;
}

export async function loadSetsCount(): Promise<number> {
  if (!_db) return 0;
  const val = await getSetting(_db, "gym_sets_count", "0");
  return parseInt(val, 10);
}

export async function saveSetsCount(count: number): Promise<void> {
  if (!_db) return;
  await setSetting(_db, "gym_sets_count", String(count));
}

export async function clearSetsCount(): Promise<void> {
  if (!_db) return;
  await setSetting(_db, "gym_sets_count", "0");
}
