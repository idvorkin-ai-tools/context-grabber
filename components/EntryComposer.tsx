import React, { useEffect, useRef, useState } from "react";
import {
  Modal,
  Platform,
  ScrollView,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import * as SQLite from "expo-sqlite";
import { momentMetaForEntry, type JournalEntry } from "../lib/journal";
import { insertAudio, insertEntry, tallyByContextFromDb } from "../lib/journalDb";
import { recordJournalMoment } from "../lib/autoDetect";
import { syncJournal, syncMoments } from "../lib/cloudkit";
import { insertMoment } from "../lib/roleMoments";
import type { RoleId } from "../lib/roles";
import { uuidV4 } from "../lib/uuid";
import {
  VoiceRecorder,
  type RecordedVoice,
  type VoiceRecorderHandle,
} from "./VoiceRecorder";
import { CopyableError } from "./CopyableError";
import { RolePickerChips } from "./RolePickerChips";

export type EntryTally = { opportunity: number; didit: number; grateful: number };

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
  /** Roles pre-selected when the composer opens (e.g. from a role detail). */
  initialRoleIds?: RoleId[];
  /** Placeholder for the multiline text field. */
  placeholder: string;
  /** Header right-side tally text, given today's counts. */
  renderTally: (t: EntryTally) => string;
  /** Card-specific content rendered above the text field. */
  children?: React.ReactNode;
  /** Build the JournalEntry to persist from the composed text/voice. */
  buildEntry: (args: {
    id: string;
    date: number;
    text: string;
    audioRecordingId: string | null;
    createdAt: number;
  }) => JournalEntry;
  /** CopyableError context label. */
  errorContext: string;
  /** Extra diagnostics merged into a copied error. */
  errorExtra?: Record<string, string>;
  /** testID prefix for the role chips. */
  roleTestIDPrefix: string;
};

/**
 * Shared "compose a journal entry" surface behind the Affirmation and
 * Grateful cards: the modal shell, today's tally, a multiline text field
 * (uncontrolled — see note below), role chips, the voice recorder, and the
 * Save / Save & add another row. Each card supplies its own top section
 * (via children), the entry builder, and the role-moment label.
 *
 * The text field is uncontrolled (defaultValue + ref.clear, no `value`) so
 * the native field isn't reconciled on every keystroke — that reconciliation
 * fights dictation/third-party keyboards (Wispr Flow) on multiline inputs.
 */
export function EntryComposer({
  visible,
  onClose,
  db,
  initialRoleIds,
  placeholder,
  renderTally,
  children,
  buildEntry,
  errorContext,
  errorExtra,
  roleTestIDPrefix,
}: Props) {
  const [pendingVoice, setPendingVoice] = useState<RecordedVoice | null>(null);
  const [saving, setSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [tally, setTally] = useState<EntryTally>({
    opportunity: 0,
    didit: 0,
    grateful: 0,
  });
  const [savedHint, setSavedHint] = useState<string | null>(null);
  const [selectedRoles, setSelectedRoles] = useState<Set<RoleId>>(new Set());
  // Mirror text into a ref for save/validation without driving `value`.
  const textRef = useRef("");
  const inputRef = useRef<TextInput>(null);
  const recorderRef = useRef<VoiceRecorderHandle>(null);

  useEffect(() => {
    if (!visible) return;
    textRef.current = "";
    inputRef.current?.clear();
    setPendingVoice(null);
    setErrorMsg(null);
    setSavedHint(null);
    setSelectedRoles(new Set(initialRoleIds ?? []));
    void refreshTally();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  async function refreshTally() {
    if (!db) return;
    setTally(await tallyByContextFromDb(db));
  }

  async function handleSave(stayOpen: boolean) {
    if (!db) {
      setErrorMsg("DB not ready");
      return;
    }
    // If a recording is still in progress, finalize it so Save captures
    // the clip (and stops the mic) instead of requiring a separate stop tap.
    let voice = pendingVoice;
    const flushed = await recorderRef.current?.flush();
    if (flushed) voice = flushed;

    const text = textRef.current.trim();
    if (!text && !voice) {
      setErrorMsg("Add a note or record voice first");
      return;
    }
    setSaving(true);
    setErrorMsg(null);
    try {
      const now = Date.now();
      let audioRecordingId: string | null = null;
      if (voice) {
        await insertAudio(db, {
          id: voice.recordingId,
          filePath: voice.filePath,
          durationMs: voice.durationMs,
          createdAt: now,
        });
        audioRecordingId = voice.recordingId;
      }
      const entry = buildEntry({
        id: uuidV4(),
        date: now,
        text,
        audioRecordingId,
        createdAt: now,
      });
      await insertEntry(db, entry);
      // Best-effort background sync; UI doesn't wait.
      void syncJournal(db);
      if (selectedRoles.size === 0) {
        // Auto-tag fallback: emo (existing behavior).
        void recordJournalMoment(db, entry);
      } else {
        // Explicit role tags override the auto-emo default. One row per
        // selected role, all sharing source_ref = entry.id so the role
        // detail's "Recent moments" can group + resolve them.
        const meta = momentMetaForEntry(entry);
        for (const roleId of selectedRoles) {
          void insertMoment(db, {
            roleId,
            timestamp: entry.date,
            what: meta.what,
            tag: meta.tag,
            source: "manual",
            sourceRef: entry.id,
          });
        }
        void syncMoments(db);
      }

      textRef.current = "";
      inputRef.current?.clear();
      setPendingVoice(null);
      setSelectedRoles(new Set());
      await refreshTally();

      if (stayOpen) {
        setSavedHint("Saved · add another");
        setTimeout(() => setSavedHint(null), 1500);
      } else {
        onClose();
      }
    } catch (e: any) {
      setErrorMsg(e?.message ?? String(e));
    } finally {
      setSaving(false);
    }
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
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.cancel}>Cancel</Text>
          </TouchableOpacity>
          <Text style={styles.tally}>{renderTally(tally)}</Text>
          <View style={{ width: 50 }} />
        </View>

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 20, paddingBottom: 40 }}
          keyboardShouldPersistTaps="handled"
          automaticallyAdjustKeyboardInsets={Platform.OS === "ios"}
        >
          {children}

          <TextInput
            ref={inputRef}
            style={styles.textInput}
            placeholder={placeholder}
            placeholderTextColor="#666"
            multiline
            defaultValue=""
            onChangeText={(t) => {
              textRef.current = t;
            }}
          />

          <RolePickerChips
            selected={selectedRoles}
            onToggle={(roleId) =>
              setSelectedRoles((prev) => {
                const next = new Set(prev);
                if (next.has(roleId)) next.delete(roleId);
                else next.add(roleId);
                return next;
              })
            }
            heading="Tag roles (optional)"
            testIDPrefix={roleTestIDPrefix}
          />

          <View style={{ marginTop: 16, alignItems: "center" }}>
            <VoiceRecorder
              ref={recorderRef}
              onRecorded={(v) => setPendingVoice(v)}
              onError={(m) => setErrorMsg(m)}
              disabled={saving}
            />
            {pendingVoice && (
              <View style={styles.voiceReady}>
                <Text style={styles.voiceReadyText}>
                  ✓ voice ready · {Math.round(pendingVoice.durationMs / 1000)}s
                </Text>
                <TouchableOpacity onPress={() => setPendingVoice(null)}>
                  <Text style={styles.voiceClear}>discard</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>

          {errorMsg && (
            <CopyableError
              message={errorMsg}
              context={errorContext}
              extra={{
                ...errorExtra,
                hasVoice: pendingVoice ? "yes" : "no",
              }}
              style={{ marginTop: 12 }}
            />
          )}
          {savedHint && <Text style={styles.savedHint}>{savedHint}</Text>}

          <View style={styles.saveRow}>
            <TouchableOpacity
              onPress={() => handleSave(true)}
              disabled={saving}
              style={[styles.saveBtn, styles.saveBtnSecondary]}
            >
              <Text style={styles.saveBtnText}>Save & add another</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => handleSave(false)}
              disabled={saving}
              style={styles.saveBtn}
            >
              <Text style={styles.saveBtnText}>{saving ? "Saving…" : "Save"}</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
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
  cancel: { color: "#4a9eff", fontSize: 16 },
  tally: { color: "#bbb", fontSize: 13, fontVariant: ["tabular-nums" as const] },
  textInput: {
    backgroundColor: "#1a1a1a",
    color: "#fff",
    borderRadius: 12,
    padding: 14,
    minHeight: 100,
    fontSize: 16,
    marginTop: 12,
    textAlignVertical: "top" as const,
  },
  voiceReady: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    justifyContent: "space-between" as const,
    marginTop: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: "#1a2a1a",
    borderRadius: 10,
  },
  voiceReadyText: { color: "#7fdf7f", fontSize: 14 },
  voiceClear: { color: "#ff8a8a", fontSize: 13 },
  savedHint: {
    color: "#7fdf7f",
    fontSize: 13,
    marginTop: 12,
    textAlign: "center" as const,
  },
  saveRow: {
    flexDirection: "row" as const,
    gap: 8,
    marginTop: 24,
  },
  saveBtn: {
    flex: 1,
    paddingVertical: 14,
    backgroundColor: "#0a4a8a",
    borderRadius: 10,
    alignItems: "center" as const,
  },
  saveBtnSecondary: { backgroundColor: "#222" },
  saveBtnText: { color: "#fff", fontSize: 15, fontWeight: "600" as const },
};
