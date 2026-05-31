import React, { useCallback, useEffect, useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import type * as SQLite from "expo-sqlite";
import {
  recentEntries,
  type AudioRecording,
  type JournalEntry,
} from "../lib/journal";
import { getAllAudio, getAllEntries } from "../lib/journalDb";
import { getRolesByEntry } from "../lib/roleMoments";
import { deleteJournalEntry } from "../lib/cloudkit";
import type { RoleId } from "../lib/roles";
import { JournalEntryRow } from "./JournalEntryRow";
import { JournalEntryRoleEditor } from "./JournalEntryRoleEditor";
import { CopyableError } from "./CopyableError";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  /** Rolling window in hours (e.g. 24). */
  windowHours: number;
  /** Section heading; default "Recent". */
  heading?: string;
  /** Bump to force a reload (e.g. after logging a new entry elsewhere). */
  reloadKey?: number;
};

/**
 * Self-contained, droppable block that shows the last `windowHours` of
 * journal entries as fully interactive rows (voice playback, delete, role
 * avatars + inline edit). Loads its own entries/audio/roles and hosts the
 * role editor + delete confirmation, so any surface can render recent
 * entries with one line.
 */
export function JournalRecentList({
  db,
  windowHours,
  heading = "Recent",
  reloadKey = 0,
}: Props) {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [audioById, setAudioById] = useState<Record<string, AudioRecording>>({});
  const [rolesByEntry, setRolesByEntry] = useState<Map<string, Set<RoleId>>>(
    new Map(),
  );
  const [editing, setEditing] = useState<JournalEntry | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!db) {
      setEntries([]);
      return;
    }
    setError(null);
    try {
      const all = await getAllEntries(db);
      setEntries(recentEntries(all, windowHours, Date.now()));
      const audio = await getAllAudio(db);
      const map: Record<string, AudioRecording> = {};
      for (const a of audio) map[a.id] = a;
      setAudioById(map);
      try {
        setRolesByEntry(await getRolesByEntry(db));
      } catch {
        setRolesByEntry(new Map());
      }
    } catch (e: any) {
      setError(e?.message ?? String(e));
    }
  }, [db, windowHours]);

  useEffect(() => {
    void load();
  }, [load, reloadKey]);

  function handleDelete(entry: JournalEntry) {
    if (!db) return;
    Alert.alert(
      "Delete entry?",
      entry.text
        ? `"${entry.text.slice(0, 80)}${entry.text.length > 80 ? "…" : ""}"`
        : "This voice entry will be deleted.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            try {
              await deleteJournalEntry(db, entry.id);
              await load();
            } catch (e: any) {
              setError(e?.message ?? String(e));
            }
          },
        },
      ],
    );
  }

  return (
    <View>
      <Text style={styles.heading}>{heading}</Text>
      {error && (
        <CopyableError
          message={error}
          context="JournalRecentList"
          style={{ marginBottom: 8 }}
        />
      )}
      {entries.length === 0 ? (
        <View style={styles.empty} testID="journal-recent-empty">
          <Text style={styles.emptyText}>
            Nothing in the last {windowHours}h. Use Affirm, Grateful, or Journal
            above.
          </Text>
        </View>
      ) : (
        entries.map((entry) => (
          <JournalEntryRow
            key={entry.id}
            entry={entry}
            audio={
              entry.audioRecordingId
                ? audioById[entry.audioRecordingId]
                : undefined
            }
            db={db}
            roles={rolesByEntry.get(entry.id) ?? null}
            onEditRoles={() => setEditing(entry)}
            onDelete={() => handleDelete(entry)}
          />
        ))
      )}
      <JournalEntryRoleEditor
        visible={editing != null}
        entry={editing}
        currentRoles={
          editing ? rolesByEntry.get(editing.id) ?? new Set() : new Set()
        }
        db={db}
        onClose={() => setEditing(null)}
        onChanged={() => void load()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  heading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  empty: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  emptyText: { color: "#888", fontSize: 13, textAlign: "center" },
});
