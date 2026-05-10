import React, { useEffect, useState } from "react";
import {
  Modal,
  Text,
  TouchableOpacity,
  View,
  ScrollView,
  Alert,
  RefreshControl,
} from "react-native";
import * as SQLite from "expo-sqlite";
import {
  type AudioRecording,
  type DayGroup,
  type JournalContext,
  type JournalEntry,
  CONTEXT_LABEL,
  groupEntries,
} from "../lib/journal";
import { getAllAudio, getAllEntries } from "../lib/journalDb";
import { deleteJournalEntry, syncJournal } from "../lib/cloudkit";
import { AudioPlayer } from "./AudioPlayer";
import { CopyableError } from "./CopyableError";

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
};

export function JournalScreen({ visible, onClose, db }: Props) {
  const [groups, setGroups] = useState<DayGroup[]>([]);
  const [audioById, setAudioById] = useState<Record<string, AudioRecording>>({});
  const [collapsedDays, setCollapsedDays] = useState<Record<string, boolean>>({});
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  async function load() {
    if (!db) return;
    setError(null);
    try {
      const entries = await getAllEntries(db);
      setGroups(groupEntries(entries));
      const audio = await getAllAudio(db);
      const map: Record<string, AudioRecording> = {};
      for (const a of audio) map[a.id] = a;
      setAudioById(map);
    } catch (e: any) {
      setError(e?.message ?? String(e));
    }
  }

  async function handleRefresh() {
    setRefreshing(true);
    try {
      if (db) await syncJournal(db);
      await load();
    } finally {
      setRefreshing(false);
    }
  }

  function toggleDay(dayKey: string) {
    setCollapsedDays((prev) => ({ ...prev, [dayKey]: !prev[dayKey] }));
  }

  async function handleDelete(entry: JournalEntry) {
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
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={{ flex: 1, backgroundColor: "#000" }}>
        <View style={styles.header}>
          <Text style={styles.title}>Journal</Text>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.done}>Done</Text>
          </TouchableOpacity>
        </View>

        {error && (
          <View style={{ paddingHorizontal: 16, paddingVertical: 6 }}>
            <CopyableError message={error} context="JournalScreen" />
          </View>
        )}

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 16, paddingBottom: 40 }}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={handleRefresh}
              tintColor="#888"
            />
          }
        >
          {groups.length === 0 ? (
            <View style={styles.emptyBlock}>
              <Text style={styles.emptyTitle}>No entries yet</Text>
              <Text style={styles.emptyHint}>
                Use Affirmation or Grateful from the dashboard to log thoughts.
                Pull down here to sync from CloudKit.
              </Text>
            </View>
          ) : (
            groups.map((day) => (
              <View key={day.dayKey} style={styles.dayBlock}>
                <TouchableOpacity onPress={() => toggleDay(day.dayKey)}>
                  <Text style={styles.dayHeader}>
                    {collapsedDays[day.dayKey] ? "▸" : "▾"} {formatDayHeader(day.dayKey)}
                  </Text>
                </TouchableOpacity>
                {!collapsedDays[day.dayKey] &&
                  day.contexts.map((ctx) => (
                    <View key={ctx.context} style={styles.contextBlock}>
                      <Text style={styles.contextHeader}>
                        {CONTEXT_LABEL[ctx.context as JournalContext]}
                      </Text>
                      {ctx.affirmations.map((a) => (
                        <View key={a.affirmationTitle} style={styles.affirmationBlock}>
                          <Text style={styles.affirmationHeader}>
                            {a.affirmationTitle}
                          </Text>
                          {a.entries.map((entry) => (
                            <EntryRow
                              key={entry.id}
                              entry={entry}
                              audio={
                                entry.audioRecordingId
                                  ? audioById[entry.audioRecordingId]
                                  : undefined
                              }
                              db={db}
                              onDelete={() => handleDelete(entry)}
                            />
                          ))}
                        </View>
                      ))}
                    </View>
                  ))}
              </View>
            ))
          )}
        </ScrollView>
      </View>
    </Modal>
  );
}

function EntryRow({
  entry,
  audio,
  db,
  onDelete,
}: {
  entry: JournalEntry;
  audio: AudioRecording | undefined;
  db: SQLite.SQLiteDatabase | null;
  onDelete: () => void;
}) {
  const time = new Date(entry.date).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
  return (
    <View style={styles.entryRow}>
      <View style={{ flex: 1 }}>
        {entry.text ? <Text style={styles.entryText}>{entry.text}</Text> : null}
        {entry.audioRecordingId && audio && (
          <View style={{ marginTop: entry.text ? 8 : 0 }}>
            <AudioPlayer
              recordingId={entry.audioRecordingId}
              durationMs={audio.durationMs}
              db={db}
            />
          </View>
        )}
        {entry.audioRecordingId && !audio && (
          <Text style={styles.entryMissing}>voice note (metadata pending sync)</Text>
        )}
        <Text style={styles.entryTime}>{time}</Text>
      </View>
      <TouchableOpacity onPress={onDelete} style={styles.deleteBtn}>
        <Text style={styles.deleteBtnText}>×</Text>
      </TouchableOpacity>
    </View>
  );
}

function formatDayHeader(dayKey: string): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);

  if (date.getTime() === today.getTime()) return "Today";
  if (date.getTime() === yesterday.getTime()) return "Yesterday";
  return date.toLocaleDateString([], {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: date.getFullYear() === today.getFullYear() ? undefined : "numeric",
  });
}

const styles = {
  header: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    justifyContent: "space-between" as const,
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomColor: "#222",
    borderBottomWidth: 1,
  },
  title: { color: "#fff", fontSize: 18, fontWeight: "600" as const },
  done: { color: "#4a9eff", fontSize: 16 },
  error: {
    color: "#ff8a8a",
    fontSize: 13,
    paddingHorizontal: 16,
    paddingVertical: 6,
  },
  emptyBlock: { paddingVertical: 80, alignItems: "center" as const },
  emptyTitle: { color: "#bbb", fontSize: 18, fontWeight: "600" as const },
  emptyHint: {
    color: "#666",
    fontSize: 13,
    textAlign: "center" as const,
    marginTop: 8,
    paddingHorizontal: 32,
  },
  dayBlock: { marginBottom: 18 },
  dayHeader: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "600" as const,
    paddingVertical: 6,
  },
  contextBlock: { marginLeft: 8, marginTop: 8 },
  contextHeader: {
    color: "#aaa",
    fontSize: 13,
    fontWeight: "600" as const,
    textTransform: "uppercase" as const,
    letterSpacing: 0.5,
    marginTop: 4,
  },
  affirmationBlock: { marginLeft: 8, marginTop: 8 },
  affirmationHeader: {
    color: "#888",
    fontSize: 13,
    fontStyle: "italic" as const,
    marginBottom: 4,
  },
  entryRow: {
    flexDirection: "row" as const,
    alignItems: "flex-start" as const,
    paddingVertical: 8,
    paddingHorizontal: 10,
    backgroundColor: "#111",
    borderRadius: 8,
    marginBottom: 6,
  },
  entryText: { color: "#fff", fontSize: 14, lineHeight: 20 },
  entryMissing: { color: "#666", fontSize: 12, fontStyle: "italic" as const },
  entryTime: { color: "#666", fontSize: 11, marginTop: 4 },
  deleteBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    marginLeft: 6,
  },
  deleteBtnText: { color: "#ff5555", fontSize: 22, fontWeight: "300" as const },
};
