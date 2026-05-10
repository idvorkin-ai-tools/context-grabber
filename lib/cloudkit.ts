import {
  configure,
  getAccountStatus,
  saveRecords,
  fetchRecord,
  createZone,
  fetchRecordZoneChanges,
  deleteRecords,
  type AccountStatus,
  type RecordToSave,
} from "expo-cloudkit";
import * as SQLite from "expo-sqlite";
import type { JournalEntry } from "./journal";
import { isJournalContext } from "./journal";
import {
  deleteEntry as deleteEntryRow,
  getPendingEntries,
  markEntryFailed,
  markEntrySynced,
  upsertSyncedEntry,
} from "./journalDb";

const CONTAINER_ID = "iCloud.com.idvorkin.contextgrabber";
const JOURNAL_ZONE = "JournalZone";
const JOURNAL_ENTRY_RECORD_TYPE = "JournalEntry";

let configured = false;
let zoneEnsured = false;

export function configureCloudKit(): void {
  if (configured) return;
  configure(CONTAINER_ID);
  configured = true;
}

export async function cloudKitAccountStatus(): Promise<AccountStatus> {
  configureCloudKit();
  return getAccountStatus();
}

export type PingResult = {
  ok: true;
  recordName: string;
  echoedTimestamp: number;
  roundTripMs: number;
} | {
  ok: false;
  error: string;
};

/**
 * P0 spike: save a SpikeRecord with `now`, fetch it back, confirm round-trip.
 * Used by the About screen "Ping CloudKit" button.
 */
export async function pingCloudKit(): Promise<PingResult> {
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return { ok: false, error: `account status: ${status}` };
    }

    const now = Date.now();
    const start = now;
    const [saved] = await saveRecords([
      {
        recordType: "SpikeRecord",
        zoneName: "_defaultZone",
        fields: { now: { type: "number", value: now } },
      },
    ]);

    const fetched = await fetchRecord(
      "SpikeRecord",
      saved.recordName,
      "_defaultZone",
    );
    const echoed = fetched.fields.now?.value as number | undefined;
    if (typeof echoed !== "number" || echoed !== now) {
      return { ok: false, error: `echo mismatch: got ${echoed}, expected ${now}` };
    }

    return {
      ok: true,
      recordName: saved.recordName,
      echoedTimestamp: echoed,
      roundTripMs: Date.now() - start,
    };
  } catch (e: any) {
    return { ok: false, error: e?.message ?? String(e) };
  }
}

// ─── Journal sync ──────────────────────────────────────────────────────────
// Source of truth: CloudKit (private DB, JournalZone). SQLite is the local
// mirror + outbound write queue. Sync runs on (a) app foreground and
// (b) after every local write — pull then push so callers see their own
// writes echoed back as `synced`. P1 is text-only; audio (CKAsset) lands
// in P2.

/** Idempotent: create JournalZone the first time, then no-op. */
async function ensureJournalZone(): Promise<void> {
  if (zoneEnsured) return;
  configureCloudKit();
  try {
    await createZone(JOURNAL_ZONE);
  } catch (e: any) {
    // Zone already exists is fine; expo-cloudkit returns a CKError with a
    // recognizable message. Anything else we re-throw.
    const msg = String(e?.message ?? e);
    if (!/already exists/i.test(msg) && !/duplicate/i.test(msg)) {
      throw e;
    }
  }
  zoneEnsured = true;
}

function entryToRecord(entry: JournalEntry): RecordToSave {
  return {
    recordType: JOURNAL_ENTRY_RECORD_TYPE,
    recordName: entry.id,
    zoneName: JOURNAL_ZONE,
    fields: {
      entryId: { type: "string", value: entry.id },
      date: { type: "number", value: entry.date },
      context: { type: "string", value: entry.context },
      affirmationTitle: { type: "string", value: entry.affirmationTitle },
      text: { type: "string", value: entry.text },
      audioRecordId: entry.audioRecordingId
        ? { type: "string", value: entry.audioRecordingId }
        : { type: "string", value: "" },
      createdAtMs: { type: "number", value: entry.createdAt },
    },
  };
}

function recordToEntry(record: {
  recordName: string;
  fields: Record<string, { value: unknown } | undefined>;
}): JournalEntry | null {
  const f = record.fields;
  const id = (f.entryId?.value as string) ?? record.recordName;
  const date = f.date?.value;
  const context = f.context?.value;
  const affirmationTitle = f.affirmationTitle?.value;
  const text = (f.text?.value as string) ?? "";
  const audioId = (f.audioRecordId?.value as string) ?? "";
  const createdAt = f.createdAtMs?.value ?? f.date?.value;

  if (
    typeof date !== "number" ||
    typeof context !== "string" ||
    !isJournalContext(context) ||
    typeof affirmationTitle !== "string" ||
    typeof createdAt !== "number"
  ) {
    return null;
  }
  return {
    id,
    date,
    context,
    affirmationTitle,
    text,
    audioRecordingId: audioId || null,
    createdAt,
  };
}

export type SyncResult = {
  ok: true;
  pulled: number;
  pushed: number;
  deleted: number;
  durationMs: number;
} | {
  ok: false;
  error: string;
  durationMs: number;
};

/**
 * Pull → push for the journal zone. Pull first so that any
 * server-authoritative changes land before we attempt to push our
 * pending mutations on top.
 */
export async function syncJournal(
  db: SQLite.SQLiteDatabase,
): Promise<SyncResult> {
  const start = Date.now();
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return {
        ok: false,
        error: `account status: ${status}`,
        durationMs: Date.now() - start,
      };
    }
    await ensureJournalZone();

    const { upserts, deletes } = await pullJournal(db);
    const { pushed } = await pushJournal(db);

    return {
      ok: true,
      pulled: upserts,
      pushed,
      deleted: deletes,
      durationMs: Date.now() - start,
    };
  } catch (e: any) {
    return {
      ok: false,
      error: e?.message ?? String(e),
      durationMs: Date.now() - start,
    };
  }
}

async function pullJournal(
  db: SQLite.SQLiteDatabase,
): Promise<{ upserts: number; deletes: number }> {
  // expo-cloudkit persists the per-zone change token natively across calls,
  // so we just call fetchRecordZoneChanges and process the delta. May
  // return moreComing=true; we loop until the server says we're current.
  let upserts = 0;
  let deletes = 0;

  while (true) {
    const result = await fetchRecordZoneChanges([JOURNAL_ZONE]);

    for (const record of result.changedRecords ?? []) {
      if (record.recordType !== JOURNAL_ENTRY_RECORD_TYPE) continue;
      const entry = recordToEntry(record as any);
      if (!entry) continue;
      await upsertSyncedEntry(
        db,
        entry,
        record.recordName,
        (record as any).changeTag ?? null,
      );
      upserts += 1;
    }

    for (const deletedName of result.deletedRecordNames ?? []) {
      await deleteEntryRow(db, deletedName);
      deletes += 1;
    }

    if (!result.moreComing) break;
  }

  return { upserts, deletes };
}

async function pushJournal(
  db: SQLite.SQLiteDatabase,
): Promise<{ pushed: number }> {
  const pending = await getPendingEntries(db);
  if (pending.length === 0) return { pushed: 0 };

  const records = pending.map(entryToRecord);
  let pushed = 0;
  try {
    const saved = await saveRecords(records);
    for (const r of saved) {
      await markEntrySynced(
        db,
        r.recordName,
        r.recordName,
        (r as any).changeTag ?? null,
      );
      pushed += 1;
    }
  } catch (e) {
    // Best-effort: mark whatever didn't make it as failed so the next
    // sync retries them. Re-throw so caller sees the error.
    for (const entry of pending) {
      const saved = await getEntryByRecordName(db, entry.id);
      if (!saved) await markEntryFailed(db, entry.id);
    }
    throw e;
  }

  return { pushed };
}

async function getEntryByRecordName(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<{ sync_state: string } | null> {
  return db.getFirstAsync<{ sync_state: string }>(
    `SELECT sync_state FROM journal_entries WHERE id = ? AND sync_state = 'synced'`,
    [id],
  );
}

/** Delete an entry locally and from CloudKit. Used by the Journal screen. */
export async function deleteJournalEntry(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await deleteEntryRow(db, id);
  configureCloudKit();
  const status = await getAccountStatus();
  if (status !== "available") return; // local-only delete is fine; sync later

  await ensureJournalZone();
  try {
    await deleteRecords([{ recordName: id, zoneName: JOURNAL_ZONE }]);
  } catch {
    // If the record never made it to CloudKit, deleteRecords throws —
    // that's fine, the local delete already happened.
  }
}
