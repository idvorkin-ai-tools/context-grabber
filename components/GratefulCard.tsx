import React from "react";
import { Text } from "react-native";
import * as SQLite from "expo-sqlite";
import { createGratitude } from "../lib/journal";
import type { RoleId } from "../lib/roles";
import { EntryComposer } from "./EntryComposer";

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
  /** Roles pre-selected when the card opens (e.g. opened from a role detail). */
  initialRoleIds?: RoleId[];
};

export function GratefulCard({ visible, onClose, db, initialRoleIds }: Props) {
  return (
    <EntryComposer
      visible={visible}
      onClose={onClose}
      db={db}
      initialRoleIds={initialRoleIds}
      placeholder="I'm grateful for…"
      renderTally={(t) => `🙏 ${t.grateful} today`}
      buildEntry={({ id, date, text, audioRecordingId, createdAt }) =>
        createGratitude({ id, date, text, audioRecordingId, createdAt })
      }
      errorContext="GratefulCard"
      roleTestIDPrefix="grateful-role"
    >
      <Text style={styles.heading}>Grateful</Text>
      <Text style={styles.prompt}>I'm grateful for…</Text>
    </EntryComposer>
  );
}

const styles = {
  heading: {
    color: "#fff",
    fontSize: 28,
    fontWeight: "700" as const,
    textAlign: "center" as const,
    marginTop: 8,
  },
  prompt: {
    color: "#888",
    fontSize: 16,
    marginTop: 8,
    fontStyle: "italic" as const,
    textAlign: "center" as const,
  },
};
