// SQLite mirror for journal entries + audio recordings.
// CloudKit is the source of truth across devices; SQLite is the local
// cache + outbound write queue. See lib/cloudkit.ts for sync engine.

import * as SQLite from "expo-sqlite";
import {
  type AudioRecording,
  type JournalContext,
  type JournalEntry,
  isJournalContext,
} from "./journal";

export type SyncState = "pending" | "synced" | "failed";

/**
 * Create journal tables. Idempotent — safe to call on every boot.
 * Schema is additive-only by policy; never drop columns or rename
 * fields here. New columns: ALTER TABLE ADD COLUMN with a default.
 */
export async function initJournalTables(
  db: SQLite.SQLiteDatabase,
): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS journal_entries (
      id              TEXT PRIMARY KEY,
      date            INTEGER NOT NULL,
      context         TEXT NOT NULL,
      affirmation     TEXT NOT NULL,
      text            TEXT NOT NULL DEFAULT '',
      audio_id        TEXT,
      created_at      INTEGER NOT NULL,
      ck_record_name  TEXT,
      ck_change_tag   TEXT,
      sync_state      TEXT NOT NULL DEFAULT 'pending'
    );
    CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(date);
    CREATE INDEX IF NOT EXISTS idx_journal_entries_sync ON journal_entries(sync_state);

    CREATE TABLE IF NOT EXISTS audio_recordings (
      id              TEXT PRIMARY KEY,
      file_path       TEXT NOT NULL,
      duration_ms     INTEGER NOT NULL,
      created_at      INTEGER NOT NULL,
      ck_record_name  TEXT,
      ck_change_tag   TEXT,
      sync_state      TEXT NOT NULL DEFAULT 'pending'
    );
    CREATE INDEX IF NOT EXISTS idx_audio_sync ON audio_recordings(sync_state);

    CREATE TABLE IF NOT EXISTS journal_sync_state (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);
}

// ── Journal entries ─────────────────────────────────────────────────────────

type EntryRow = {
  id: string;
  date: number;
  context: string;
  affirmation: string;
  text: string;
  audio_id: string | null;
  created_at: number;
};

function rowToEntry(r: EntryRow): JournalEntry {
  if (!isJournalContext(r.context)) {
    // Forward-compat: unknown context strings get rejected at the boundary
    // rather than silently rendered. Future contexts must be added to
    // JournalContext.
    throw new Error(`unknown journal context "${r.context}"`);
  }
  return {
    id: r.id,
    date: r.date,
    context: r.context,
    affirmationTitle: r.affirmation,
    text: r.text,
    audioRecordingId: r.audio_id,
    createdAt: r.created_at,
  };
}

export async function insertEntry(
  db: SQLite.SQLiteDatabase,
  entry: JournalEntry,
): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO journal_entries
       (id, date, context, affirmation, text, audio_id, created_at, sync_state)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`,
    [
      entry.id,
      entry.date,
      entry.context,
      entry.affirmationTitle,
      entry.text,
      entry.audioRecordingId,
      entry.createdAt,
    ],
  );
}

/** Upsert from a CloudKit pull — caller already has the record name + change tag. */
export async function upsertSyncedEntry(
  db: SQLite.SQLiteDatabase,
  entry: JournalEntry,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO journal_entries
       (id, date, context, affirmation, text, audio_id, created_at, ck_record_name, ck_change_tag, sync_state)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced')`,
    [
      entry.id,
      entry.date,
      entry.context,
      entry.affirmationTitle,
      entry.text,
      entry.audioRecordingId,
      entry.createdAt,
      ckRecordName,
      ckChangeTag,
    ],
  );
}

export async function markEntrySynced(
  db: SQLite.SQLiteDatabase,
  id: string,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `UPDATE journal_entries
        SET ck_record_name = ?, ck_change_tag = ?, sync_state = 'synced'
      WHERE id = ?`,
    [ckRecordName, ckChangeTag, id],
  );
}

export async function markEntryFailed(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await db.runAsync(
    `UPDATE journal_entries SET sync_state = 'failed' WHERE id = ?`,
    [id],
  );
}

export async function deleteEntry(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await db.runAsync(`DELETE FROM journal_entries WHERE id = ?`, [id]);
}

export async function getEntry(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<JournalEntry | null> {
  const row = await db.getFirstAsync<EntryRow>(
    `SELECT id, date, context, affirmation, text, audio_id, created_at
       FROM journal_entries WHERE id = ?`,
    [id],
  );
  return row ? rowToEntry(row) : null;
}

/**
 * Batch-fetch entries by id, newest-first. Used by the role detail sheet
 * to resolve the journal entries its moments point at. Unknown ids are
 * silently skipped (the entry may have been deleted).
 */
export async function getEntriesByIds(
  db: SQLite.SQLiteDatabase,
  ids: string[],
): Promise<JournalEntry[]> {
  if (ids.length === 0) return [];
  const placeholders = ids.map(() => "?").join(", ");
  const rows = await db.getAllAsync<EntryRow>(
    `SELECT id, date, context, affirmation, text, audio_id, created_at
       FROM journal_entries WHERE id IN (${placeholders}) ORDER BY date DESC`,
    ids,
  );
  return rows.map(rowToEntry);
}

export async function getAllEntries(
  db: SQLite.SQLiteDatabase,
): Promise<JournalEntry[]> {
  const rows = await db.getAllAsync<EntryRow>(
    `SELECT id, date, context, affirmation, text, audio_id, created_at
       FROM journal_entries ORDER BY date DESC`,
  );
  return rows.map(rowToEntry);
}

export async function getPendingEntries(
  db: SQLite.SQLiteDatabase,
): Promise<JournalEntry[]> {
  const rows = await db.getAllAsync<EntryRow>(
    `SELECT id, date, context, affirmation, text, audio_id, created_at
       FROM journal_entries
      WHERE sync_state IN ('pending', 'failed')
      ORDER BY date ASC`,
  );
  return rows.map(rowToEntry);
}

export async function countEntries(
  db: SQLite.SQLiteDatabase,
): Promise<{ total: number; pending: number; synced: number; failed: number }> {
  const totalRow = await db.getFirstAsync<{ n: number }>(
    `SELECT COUNT(*) as n FROM journal_entries`,
  );
  const pendingRow = await db.getFirstAsync<{ n: number }>(
    `SELECT COUNT(*) as n FROM journal_entries WHERE sync_state = 'pending'`,
  );
  const syncedRow = await db.getFirstAsync<{ n: number }>(
    `SELECT COUNT(*) as n FROM journal_entries WHERE sync_state = 'synced'`,
  );
  const failedRow = await db.getFirstAsync<{ n: number }>(
    `SELECT COUNT(*) as n FROM journal_entries WHERE sync_state = 'failed'`,
  );
  return {
    total: totalRow?.n ?? 0,
    pending: pendingRow?.n ?? 0,
    synced: syncedRow?.n ?? 0,
    failed: failedRow?.n ?? 0,
  };
}

// ── Tally for the cards ─────────────────────────────────────────────────────
// Counts today's entries by context. Today is local-day; we avoid importing
// `dayKey` here to keep journalDb dependency-light, computing the local
// midnight bounds inline.

export async function tallyByContextFromDb(
  db: SQLite.SQLiteDatabase,
  now: Date = new Date(),
): Promise<{ opportunity: number; didit: number; grateful: number }> {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  const startMs = start.getTime();
  const endMs = end.getTime();

  const rows = await db.getAllAsync<{ context: string; n: number }>(
    `SELECT context, COUNT(*) as n
       FROM journal_entries
      WHERE date >= ? AND date < ?
      GROUP BY context`,
    [startMs, endMs],
  );
  const tally = { opportunity: 0, didit: 0, grateful: 0 };
  for (const row of rows) {
    if (isJournalContext(row.context)) {
      tally[row.context] = row.n;
    }
  }
  return tally;
}

// ── Audio recordings ────────────────────────────────────────────────────────

type AudioRow = {
  id: string;
  file_path: string;
  duration_ms: number;
  created_at: number;
};

function rowToAudio(r: AudioRow): AudioRecording {
  return {
    id: r.id,
    filePath: r.file_path,
    durationMs: r.duration_ms,
    createdAt: r.created_at,
  };
}

export async function insertAudio(
  db: SQLite.SQLiteDatabase,
  audio: AudioRecording,
): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO audio_recordings
       (id, file_path, duration_ms, created_at, sync_state)
     VALUES (?, ?, ?, ?, 'pending')`,
    [audio.id, audio.filePath, audio.durationMs, audio.createdAt],
  );
}

export async function markAudioSynced(
  db: SQLite.SQLiteDatabase,
  id: string,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `UPDATE audio_recordings
        SET ck_record_name = ?, ck_change_tag = ?, sync_state = 'synced'
      WHERE id = ?`,
    [ckRecordName, ckChangeTag, id],
  );
}

export async function getAudio(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<AudioRecording | null> {
  const row = await db.getFirstAsync<AudioRow>(
    `SELECT id, file_path, duration_ms, created_at FROM audio_recordings WHERE id = ?`,
    [id],
  );
  return row ? rowToAudio(row) : null;
}

export async function getAllAudio(
  db: SQLite.SQLiteDatabase,
): Promise<AudioRecording[]> {
  const rows = await db.getAllAsync<AudioRow>(
    `SELECT id, file_path, duration_ms, created_at
       FROM audio_recordings ORDER BY created_at DESC`,
  );
  return rows.map(rowToAudio);
}

export async function getPendingAudio(
  db: SQLite.SQLiteDatabase,
): Promise<AudioRecording[]> {
  const rows = await db.getAllAsync<AudioRow>(
    `SELECT id, file_path, duration_ms, created_at
       FROM audio_recordings
      WHERE sync_state IN ('pending', 'failed')
      ORDER BY created_at ASC`,
  );
  return rows.map(rowToAudio);
}

// ── Sync cursor (CloudKit zone-changes token) ───────────────────────────────

export async function getSyncToken(
  db: SQLite.SQLiteDatabase,
  key: string,
): Promise<string | null> {
  const row = await db.getFirstAsync<{ value: string }>(
    `SELECT value FROM journal_sync_state WHERE key = ?`,
    [key],
  );
  return row?.value ?? null;
}

export async function setSyncToken(
  db: SQLite.SQLiteDatabase,
  key: string,
  token: string,
): Promise<void> {
  await db.runAsync(
    `INSERT OR REPLACE INTO journal_sync_state (key, value) VALUES (?, ?)`,
    [key, token],
  );
}

// Re-exported helper for callers that need to introspect sync queue counts.
export type { JournalContext };
