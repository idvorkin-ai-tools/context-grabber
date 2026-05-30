// Pure functions + types for the affirmation/gratitude journal.
// Storage lives in lib/journalDb.ts (SQLite) and lib/cloudkit.ts (sync).
// This module is the SHAPE — what an entry is, how to group, what to export.

import { ALL_AFFIRMATION_TITLES, GRATEFUL_BUCKET } from "./affirmations";

export type JournalContext = "opportunity" | "didit" | "grateful";

export const JOURNAL_CONTEXTS: readonly JournalContext[] = [
  "opportunity",
  "didit",
  "grateful",
] as const;

export const CONTEXT_LABEL: Record<JournalContext, string> = {
  opportunity: "Opportunities",
  didit: "Did Its",
  grateful: "Gratitudes",
};

export type JournalEntry = {
  /** Stable UUID; primary key in SQLite, recordName in CloudKit. */
  id: string;
  /** Local-time millis of when the user logged the entry. */
  date: number;
  context: JournalContext;
  /** One of AFFIRMATIONS[].title, or "Grateful" for grateful-card entries. */
  affirmationTitle: string;
  /** Freeform text. Empty string when the entry is voice-only. */
  text: string;
  /** Paired AudioRecording id, or null for text-only entries. */
  audioRecordingId: string | null;
  /** Server-set on first sync; not user-visible. */
  createdAt: number;
};

export type AudioRecording = {
  id: string;
  /** Local file URI under documents/voice/. */
  filePath: string;
  durationMs: number;
  createdAt: number;
};

// ── Validation ──────────────────────────────────────────────────────────────

export function isJournalContext(s: unknown): s is JournalContext {
  return s === "opportunity" || s === "didit" || s === "grateful";
}

export function isKnownAffirmationTitle(title: string): boolean {
  return ALL_AFFIRMATION_TITLES.includes(title);
}

// ── Day key (local-time YYYY-MM-DD) ─────────────────────────────────────────
// Journal grouping is by local calendar day, mirroring the rest of the app.

export function dayKey(timestamp: number, now: Date = new Date(timestamp)): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

// ── Grouping for the Journal screen ─────────────────────────────────────────
// date → context → affirmation → entries (newest-first within a leaf).

export type AffirmationGroup = {
  affirmationTitle: string;
  entries: JournalEntry[];
};

export type ContextGroup = {
  context: JournalContext;
  affirmations: AffirmationGroup[];
};

export type DayGroup = {
  dayKey: string;
  contexts: ContextGroup[];
};

/**
 * Group entries by date → context → affirmation. Newest-first at every
 * level. Empty contexts/affirmations are pruned.
 */
export function groupEntries(entries: JournalEntry[]): DayGroup[] {
  if (entries.length === 0) return [];

  const byDay = new Map<string, Map<JournalContext, Map<string, JournalEntry[]>>>();

  for (const entry of entries) {
    const day = dayKey(entry.date);
    let dayMap = byDay.get(day);
    if (!dayMap) {
      dayMap = new Map();
      byDay.set(day, dayMap);
    }
    let contextMap = dayMap.get(entry.context);
    if (!contextMap) {
      contextMap = new Map();
      dayMap.set(entry.context, contextMap);
    }
    const affKey = entry.affirmationTitle;
    let bucket = contextMap.get(affKey);
    if (!bucket) {
      bucket = [];
      contextMap.set(affKey, bucket);
    }
    bucket.push(entry);
  }

  const days: DayGroup[] = [];
  // Newest day first (lexicographic descending works for YYYY-MM-DD).
  const sortedDays = [...byDay.keys()].sort((a, b) => b.localeCompare(a));
  for (const day of sortedDays) {
    const dayMap = byDay.get(day)!;
    const contexts: ContextGroup[] = [];
    // Fixed context order: opp → did → grateful.
    for (const ctx of JOURNAL_CONTEXTS) {
      const contextMap = dayMap.get(ctx);
      if (!contextMap || contextMap.size === 0) continue;
      const affirmations: AffirmationGroup[] = [];
      // Affirmations within a context: known order first, then any
      // unrecognized titles alphabetically (defensive — known shouldn't
      // change but old data might carry historical names).
      const titles = [...contextMap.keys()].sort((a, b) => {
        const ai = ALL_AFFIRMATION_TITLES.indexOf(a);
        const bi = ALL_AFFIRMATION_TITLES.indexOf(b);
        if (ai === -1 && bi === -1) return a.localeCompare(b);
        if (ai === -1) return 1;
        if (bi === -1) return -1;
        return ai - bi;
      });
      for (const title of titles) {
        const bucket = contextMap.get(title)!;
        bucket.sort((a, b) => b.date - a.date);
        affirmations.push({ affirmationTitle: title, entries: bucket });
      }
      contexts.push({ context: ctx, affirmations });
    }
    days.push({ dayKey: day, contexts });
  }

  return days;
}

// ── Tally for the card chip ─────────────────────────────────────────────────

export function tallyByContext(
  entries: JournalEntry[],
  forDayKey: string,
): Record<JournalContext, number> {
  const tally: Record<JournalContext, number> = {
    opportunity: 0,
    didit: 0,
    grateful: 0,
  };
  for (const entry of entries) {
    if (dayKey(entry.date) === forDayKey) {
      tally[entry.context] += 1;
    }
  }
  return tally;
}

// ── Entry creation helpers ──────────────────────────────────────────────────

/**
 * Build an entry record. `id` and timestamps are caller-provided so the
 * function stays pure + testable; production code passes a uuid + Date.now().
 */
export function createEntry(args: {
  id: string;
  date: number;
  context: JournalContext;
  affirmationTitle: string;
  text?: string;
  audioRecordingId?: string | null;
  createdAt?: number;
}): JournalEntry {
  return {
    id: args.id,
    date: args.date,
    context: args.context,
    affirmationTitle: args.affirmationTitle,
    text: args.text ?? "",
    audioRecordingId: args.audioRecordingId ?? null,
    createdAt: args.createdAt ?? args.date,
  };
}

/** Convenience: a Grateful Card entry always uses the Grateful bucket. */
export function createGratitude(args: {
  id: string;
  date: number;
  text?: string;
  audioRecordingId?: string | null;
  createdAt?: number;
}): JournalEntry {
  return createEntry({
    ...args,
    context: "grateful",
    affirmationTitle: GRATEFUL_BUCKET,
  });
}

/**
 * Label + tag for a role-tag moment derived from a journal entry. Affirmation
 * entries surface the affirmation title; gratitudes surface the gratitude
 * text (falling back to "Grateful" for voice-only entries). The tag is always
 * the entry's context. Pure, so the role-moment shape stays testable.
 */
export function momentMetaForEntry(entry: JournalEntry): {
  what: string;
  tag: JournalContext;
} {
  if (entry.context === "grateful") {
    return { what: entry.text || "Grateful", tag: entry.context };
  }
  return { what: entry.affirmationTitle, tag: entry.context };
}
