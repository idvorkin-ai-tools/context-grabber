import React, { useEffect, useRef, useState } from "react";
import { Text, TouchableOpacity, View } from "react-native";
import * as SQLite from "expo-sqlite";
import {
  AFFIRMATIONS,
  getRandomAffirmationIndex,
  type Affirmation,
} from "../lib/affirmations";
import { createEntry, type JournalContext } from "../lib/journal";
import type { RoleId } from "../lib/roles";
import { EntryComposer } from "./EntryComposer";

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
  /** Roles pre-selected when the card opens (e.g. opened from a role detail). */
  initialRoleIds?: RoleId[];
};

const PROMPTS: Record<JournalContext, string> = {
  opportunity: "How will you apply this today?",
  didit: "How did you apply this?",
  grateful: "I'm grateful for…",
};

export function AffirmationCard({ visible, onClose, db, initialRoleIds }: Props) {
  const [index, setIndex] = useState(() => getRandomAffirmationIndex());
  const [picker, setPicker] = useState(false);
  const [context, setContext] = useState<JournalContext>("opportunity");
  const lastIndexRef = useRef(index);

  const affirmation: Affirmation = AFFIRMATIONS[index];

  // Re-randomize the affirmation on each open (rotating exposure is the point).
  useEffect(() => {
    if (!visible) return;
    const next = getRandomAffirmationIndex(lastIndexRef.current);
    setIndex(next);
    lastIndexRef.current = next;
    setPicker(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  function selectAffirmation(i: number) {
    setIndex(i);
    lastIndexRef.current = i;
    setPicker(false);
  }

  return (
    <EntryComposer
      visible={visible}
      onClose={onClose}
      db={db}
      initialRoleIds={initialRoleIds}
      placeholder={PROMPTS[context]}
      renderTally={(t) => `☀️ ${t.opportunity}  ✓ ${t.didit}  🙏 ${t.grateful}`}
      buildEntry={({ id, date, text, audioRecordingId, createdAt }) =>
        createEntry({
          id,
          date,
          context,
          affirmationTitle: affirmation.title,
          text,
          audioRecordingId,
          createdAt,
        })
      }
      errorContext="AffirmationCard"
      errorExtra={{ affirmation: affirmation.title, ctx: context }}
      roleTestIDPrefix="affirm-role"
    >
      {({ recorder }) => (
        <>
          <TouchableOpacity
            onPress={() => setPicker(!picker)}
            style={styles.affirmationBlock}
          >
            <Text style={styles.affirmationTitle}>{affirmation.title}</Text>
            <Text style={styles.affirmationSubtitle}>{affirmation.subtitle}</Text>
            <Text style={styles.swapHint}>tap to choose a different one</Text>
          </TouchableOpacity>

          {picker && (
            <View style={styles.pickerBox}>
              {AFFIRMATIONS.map((a, i) => (
                <TouchableOpacity
                  key={a.title}
                  onPress={() => selectAffirmation(i)}
                  style={[styles.pickerRow, i === index && styles.pickerRowActive]}
                >
                  <Text style={styles.pickerTitle}>{a.title}</Text>
                  <Text style={styles.pickerSubtitle}>{a.subtitle}</Text>
                </TouchableOpacity>
              ))}
            </View>
          )}

          <View style={styles.contextRow}>
            <ContextButton
              active={context === "opportunity"}
              label="🎯 Opportunity"
              onPress={() => setContext("opportunity")}
            />
            <ContextButton
              active={context === "didit"}
              label="✓ Did It"
              onPress={() => setContext("didit")}
            />
            {recorder}
          </View>

          <Text style={styles.prompt}>{PROMPTS[context]}</Text>
        </>
      )}
    </EntryComposer>
  );
}

function ContextButton({
  active,
  label,
  onPress,
}: {
  active: boolean;
  label: string;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity
      onPress={onPress}
      style={[styles.contextBtn, active && styles.contextBtnActive]}
    >
      <Text
        style={[styles.contextBtnText, active && styles.contextBtnTextActive]}
      >
        {label}
      </Text>
    </TouchableOpacity>
  );
}

const styles = {
  affirmationBlock: {
    paddingVertical: 18,
    borderBottomColor: "#222",
    borderBottomWidth: 1,
  },
  affirmationTitle: {
    color: "#fff",
    fontSize: 24,
    fontWeight: "700" as const,
    textAlign: "center" as const,
  },
  affirmationSubtitle: {
    color: "#bbb",
    fontSize: 14,
    textAlign: "center" as const,
    marginTop: 6,
    fontStyle: "italic" as const,
  },
  swapHint: {
    color: "#666",
    fontSize: 11,
    textAlign: "center" as const,
    marginTop: 8,
  },
  pickerBox: {
    marginTop: 12,
    backgroundColor: "#111",
    borderRadius: 12,
    padding: 8,
  },
  pickerRow: { padding: 12, borderRadius: 8 },
  pickerRowActive: { backgroundColor: "#1f2a3a" },
  pickerTitle: { color: "#fff", fontSize: 16, fontWeight: "600" as const },
  pickerSubtitle: { color: "#999", fontSize: 12, marginTop: 2 },
  contextRow: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    gap: 8,
    marginTop: 18,
  },
  contextBtn: {
    flex: 1,
    paddingVertical: 14,
    backgroundColor: "#1a1a1a",
    borderRadius: 10,
    alignItems: "center" as const,
  },
  contextBtnActive: { backgroundColor: "#0a4a8a" },
  contextBtnText: { color: "#aaa", fontSize: 15, fontWeight: "600" as const },
  contextBtnTextActive: { color: "#fff" },
  prompt: {
    color: "#888",
    fontSize: 14,
    marginTop: 16,
    fontStyle: "italic" as const,
  },
};
