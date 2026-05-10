// JSON export/import for the journal — the durable file backup that
// insulates Igor from any CloudKit oddity (per the safety-net promise
// in 2026-05-10-affirmations-journal-design.md).
//
// Shape kept close to Humane Tracker's export so hand-conversion in
// either direction is possible if needed; not promised round-trippable
// at the binary level (audio blobs are referenced by id only).

import type { AudioRecording, JournalEntry } from "./journal";

export const JOURNAL_EXPORT_VERSION = 1 as const;

export type JournalExport = {
  version: typeof JOURNAL_EXPORT_VERSION;
  exportedAt: string; // ISO 8601 UTC
  app: "context-grabber";
  entries: ExportedEntry[];
  audioRecordings: ExportedAudio[];
};

export type ExportedEntry = {
  id: string;
  date: string; // ISO 8601 UTC
  context: "opportunity" | "didit" | "grateful";
  affirmationTitle: string;
  text: string;
  audioRecordingId: string | null;
  createdAt: string;
};

export type ExportedAudio = {
  id: string;
  /** Local path on the source device. Not portable — recipient should
   *  treat as a stable id, not a real path. */
  filePath: string;
  durationMs: number;
  createdAt: string;
};

export function buildJournalExport(
  entries: JournalEntry[],
  audioRecordings: AudioRecording[],
  now: Date = new Date(),
): JournalExport {
  return {
    version: JOURNAL_EXPORT_VERSION,
    exportedAt: now.toISOString(),
    app: "context-grabber",
    entries: entries.map(entryToExport),
    audioRecordings: audioRecordings.map(audioToExport),
  };
}

function entryToExport(e: JournalEntry): ExportedEntry {
  return {
    id: e.id,
    date: new Date(e.date).toISOString(),
    context: e.context,
    affirmationTitle: e.affirmationTitle,
    text: e.text,
    audioRecordingId: e.audioRecordingId,
    createdAt: new Date(e.createdAt).toISOString(),
  };
}

function audioToExport(a: AudioRecording): ExportedAudio {
  return {
    id: a.id,
    filePath: a.filePath,
    durationMs: a.durationMs,
    createdAt: new Date(a.createdAt).toISOString(),
  };
}

// ── Import (used by P4 Humane Tracker import) ───────────────────────────────

export type ImportResult = {
  entries: JournalEntry[];
  audioRecordings: AudioRecording[];
};

/**
 * Parse a JournalExport blob (from this app or a Humane Tracker JSON
 * backup) into the in-memory shape callers can pass to journalDb.
 * Strict on structure but lenient on missing optional fields so we can
 * import partial/legacy data.
 */
export function parseJournalExport(raw: unknown): ImportResult {
  if (!raw || typeof raw !== "object") {
    throw new Error("not an object");
  }
  const obj = raw as Record<string, unknown>;
  const entriesRaw = obj.entries;
  const audioRaw = obj.audioRecordings;
  if (!Array.isArray(entriesRaw)) {
    throw new Error("entries: expected array");
  }
  const entries: JournalEntry[] = entriesRaw.map((e, i) => parseEntry(e, i));
  const audioRecordings: AudioRecording[] = Array.isArray(audioRaw)
    ? audioRaw.map((a, i) => parseAudio(a, i))
    : [];
  return { entries, audioRecordings };
}

function parseEntry(raw: unknown, index: number): JournalEntry {
  if (!raw || typeof raw !== "object") {
    throw new Error(`entries[${index}]: expected object`);
  }
  const o = raw as Record<string, unknown>;
  const id = mustString(o, "id", `entries[${index}]`);
  const date = mustDate(o, "date", `entries[${index}]`);
  const ctx = mustString(o, "context", `entries[${index}]`);
  if (ctx !== "opportunity" && ctx !== "didit" && ctx !== "grateful") {
    throw new Error(`entries[${index}].context: unknown "${ctx}"`);
  }
  const affirmationTitle = mustString(
    o,
    "affirmationTitle",
    `entries[${index}]`,
  );
  const text = typeof o.text === "string" ? o.text : "";
  const audioRecordingId =
    typeof o.audioRecordingId === "string" ? o.audioRecordingId : null;
  const createdAt =
    o.createdAt !== undefined ? mustDate(o, "createdAt", `entries[${index}]`) : date;
  return { id, date, context: ctx, affirmationTitle, text, audioRecordingId, createdAt };
}

function parseAudio(raw: unknown, index: number): AudioRecording {
  if (!raw || typeof raw !== "object") {
    throw new Error(`audioRecordings[${index}]: expected object`);
  }
  const o = raw as Record<string, unknown>;
  const id = mustString(o, "id", `audioRecordings[${index}]`);
  const filePath = mustString(o, "filePath", `audioRecordings[${index}]`);
  const durationMs = mustNumber(o, "durationMs", `audioRecordings[${index}]`);
  const createdAt = mustDate(o, "createdAt", `audioRecordings[${index}]`);
  return { id, filePath, durationMs, createdAt };
}

function mustString(o: Record<string, unknown>, key: string, ctx: string): string {
  const v = o[key];
  if (typeof v !== "string") throw new Error(`${ctx}.${key}: expected string`);
  return v;
}

function mustNumber(o: Record<string, unknown>, key: string, ctx: string): number {
  const v = o[key];
  if (typeof v !== "number" || !Number.isFinite(v)) {
    throw new Error(`${ctx}.${key}: expected number`);
  }
  return v;
}

function mustDate(o: Record<string, unknown>, key: string, ctx: string): number {
  const v = o[key];
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const ms = Date.parse(v);
    if (Number.isFinite(ms)) return ms;
  }
  throw new Error(`${ctx}.${key}: expected ISO date or unix-ms number`);
}
