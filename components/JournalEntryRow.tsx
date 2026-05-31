import React from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import type * as SQLite from "expo-sqlite";
import type { AudioRecording, JournalEntry } from "../lib/journal";
import { ROLES, getRole, type RoleId } from "../lib/roles";
import { RoleAvatar } from "./RoleAvatar";
import { AudioPlayer } from "./AudioPlayer";

/** Canonical role order, shared by the row avatars and the journal grouping. */
export const ROLE_ORDER: RoleId[] = ROLES.map((r) => r.id);

/**
 * One interactive journal entry: text, inline voice playback, a delete
 * affordance, and the entry's role tags as small avatars that open an
 * editor on tap. Shared by the full Journal modal and the Mind tab's
 * recent list so the two never diverge.
 */
export function JournalEntryRow({
  entry,
  audio,
  db,
  roles,
  onEditRoles,
  onDelete,
}: {
  entry: JournalEntry;
  audio: AudioRecording | undefined;
  db: SQLite.SQLiteDatabase | null;
  roles: ReadonlySet<RoleId> | null;
  onEditRoles: () => void;
  onDelete: () => void;
}) {
  const time = new Date(entry.date).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
  const roleIds = roles ? ROLE_ORDER.filter((id) => roles.has(id)) : [];
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
        <View style={styles.entryFooter}>
          <Text style={styles.entryTime}>{time}</Text>
          <TouchableOpacity
            onPress={onEditRoles}
            style={styles.roleTagBtn}
            testID={`entry-roles-${entry.id}`}
            accessibilityLabel="Edit role tags"
          >
            {roleIds.map((id) => (
              <RoleAvatar key={id} roleId={id} size={16} ringColor={getRole(id).color} />
            ))}
            <Text style={styles.roleTagPlus}>
              {roleIds.length === 0 ? "+ tag" : "＋"}
            </Text>
          </TouchableOpacity>
        </View>
      </View>
      <TouchableOpacity onPress={onDelete} style={styles.deleteBtn}>
        <Text style={styles.deleteBtnText}>×</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  entryRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    paddingVertical: 8,
    paddingHorizontal: 10,
    backgroundColor: "#111",
    borderRadius: 8,
    marginBottom: 6,
  },
  entryText: { color: "#fff", fontSize: 14, lineHeight: 20 },
  entryMissing: { color: "#666", fontSize: 12, fontStyle: "italic" },
  entryTime: { color: "#666", fontSize: 11 },
  entryFooter: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 4,
  },
  roleTagBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 3,
    paddingVertical: 2,
    paddingHorizontal: 4,
  },
  roleTagPlus: { color: "#6f7891", fontSize: 12, marginLeft: 2 },
  deleteBtn: { paddingHorizontal: 8, paddingVertical: 4, marginLeft: 6 },
  deleteBtnText: { color: "#ff5555", fontSize: 22, fontWeight: "300" },
});
