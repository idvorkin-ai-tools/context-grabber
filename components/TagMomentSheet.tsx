import React, { useEffect, useState } from "react";
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import { ROLES, type RoleId } from "../lib/roles";
import { insertMoment } from "../lib/roleMoments";
import { syncMoments } from "../lib/cloudkit";
import { RoleAvatar } from "./RoleAvatar";

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
  /** Role pre-selected when the sheet opens (e.g. from a long-press on a role row). */
  initialRoleId?: RoleId;
  /** Called after a save so the parent can refresh its data. */
  onSaved?: () => void;
};

/**
 * Modal for capturing a manual "moment" against a role. Spec:
 * "long-press → 'Tag as moment for Role…' → role picker → optional
 * one-line caption". This is the role picker.
 */
export function TagMomentSheet({
  visible,
  onClose,
  db,
  initialRoleId,
  onSaved,
}: Props) {
  const [selectedRoles, setSelectedRoles] = useState<Set<RoleId>>(() =>
    initialRoleId ? new Set([initialRoleId]) : new Set(),
  );
  const [caption, setCaption] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (visible) {
      setSelectedRoles(initialRoleId ? new Set([initialRoleId]) : new Set());
      setCaption("");
      setError(null);
    }
  }, [visible, initialRoleId]);

  function toggleRole(id: RoleId) {
    setSelectedRoles((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function save() {
    if (!db || selectedRoles.size === 0) return;
    setSaving(true);
    setError(null);
    try {
      const ts = Date.now();
      const what =
        caption.trim() === ""
          ? defaultWhat([...selectedRoles][0]!)
          : caption.trim();
      for (const roleId of selectedRoles) {
        await insertMoment(db, {
          roleId,
          timestamp: ts,
          what,
          tag: null,
          source: "manual",
          sourceRef: null,
        });
      }
      // Best-effort push so the moment lands on other devices quickly.
      // Failure is non-fatal: the row is sync_state='pending' and the
      // next app-foreground sync will retry.
      void syncMoments(db);
      onSaved?.();
      onClose();
    } catch (e: any) {
      setError(e?.message ?? "Save failed");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      onRequestClose={onClose}
    >
      <View style={styles.backdrop}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : undefined}
          style={styles.sheet}
        >
          <View style={styles.handle} />
          <View style={styles.header}>
            <Text style={styles.heading}>Tag a moment</Text>
            <TouchableOpacity onPress={onClose} testID="tag-sheet-close">
              <Text style={styles.close}>✕</Text>
            </TouchableOpacity>
          </View>

          <Text style={styles.subheading}>
            Pick role(s) — tap to toggle
          </Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.rolePicker}
          >
            {ROLES.map((r) => {
              const selected = selectedRoles.has(r.id);
              return (
                <Pressable
                  key={r.id}
                  onPress={() => toggleRole(r.id)}
                  style={[
                    styles.roleChip,
                    selected && {
                      borderColor: r.color,
                      backgroundColor: hexWithAlpha(r.color, 0.18),
                    },
                  ]}
                  testID={`tag-pick-${r.id}`}
                  accessibilityState={{ selected }}
                >
                  <RoleAvatar
                    roleId={r.id}
                    size={36}
                    ringColor={selected ? r.color : undefined}
                  />
                  <Text
                    style={[
                      styles.chipLabel,
                      selected && { color: r.color, fontWeight: "700" },
                    ]}
                    numberOfLines={1}
                  >
                    {r.short}
                  </Text>
                </Pressable>
              );
            })}
          </ScrollView>

          <Text style={styles.subheading}>What happened? (optional)</Text>
          <TextInput
            value={caption}
            onChangeText={setCaption}
            placeholder={
              selectedRoles.size > 0
                ? defaultWhat([...selectedRoles][0]!)
                : "date night, gym, call…"
            }
            placeholderTextColor="#666"
            style={styles.input}
            multiline
            maxLength={140}
            testID="tag-caption"
          />

          {error && <Text style={styles.error}>{error}</Text>}

          <TouchableOpacity
            onPress={save}
            disabled={selectedRoles.size === 0 || saving}
            style={[
              styles.saveBtn,
              (selectedRoles.size === 0 || saving) && styles.saveBtnDisabled,
            ]}
            testID="tag-save"
          >
            <Text style={styles.saveBtnText}>
              {saving
                ? "Saving…"
                : `Save${selectedRoles.size > 1 ? ` (${selectedRoles.size})` : ""}`}
            </Text>
          </TouchableOpacity>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

function defaultWhat(roleId: RoleId): string {
  switch (roleId) {
    case "tori":
      return "Time with Tori";
    case "amelia":
      return "Time with Amelia";
    case "zach":
      return "Time with Zach";
    case "family":
      return "Family time";
    case "fit":
      return "Moved my body";
    case "emo":
      return "Inner work";
    case "tech":
      return "Built something";
    case "pro":
      return "Work win";
    case "carfree":
      return "Walked / biked";
    case "smiles":
      return "Spread a smile";
    case "habits":
      return "Habit reps";
  }
}

function hexWithAlpha(hex: string, alpha: number): string {
  const m = /^#([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const a = Math.round(alpha * 255).toString(16).padStart(2, "0");
  return `#${m[1]}${a}`;
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.6)",
    justifyContent: "flex-end",
  },
  sheet: {
    backgroundColor: "#111828",
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: Platform.OS === "ios" ? 32 : 16,
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#444",
    alignSelf: "center",
    marginBottom: 8,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 4,
  },
  heading: {
    color: "#e0e0e0",
    fontSize: 18,
    fontWeight: "700",
  },
  close: { color: "#888", fontSize: 20, paddingHorizontal: 8 },
  subheading: {
    color: "#888",
    fontSize: 12,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 14,
    marginBottom: 8,
  },
  rolePicker: {
    paddingVertical: 4,
    gap: 8,
  },
  roleChip: {
    width: 72,
    paddingVertical: 10,
    paddingHorizontal: 6,
    borderRadius: 12,
    backgroundColor: "#1a1f2e",
    borderWidth: 1,
    borderColor: "transparent",
    alignItems: "center",
    marginRight: 6,
  },
  chipLabel: {
    color: "#aaa",
    fontSize: 11,
    marginTop: 6,
    textAlign: "center",
  },
  input: {
    color: "#e0e0e0",
    backgroundColor: "#1a1a2e",
    borderRadius: 10,
    padding: 12,
    fontSize: 14,
    minHeight: 60,
    textAlignVertical: "top",
  },
  error: { color: "#ff6b6b", fontSize: 13, marginTop: 8 },
  saveBtn: {
    backgroundColor: "#2d6a4f",
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 16,
  },
  saveBtnDisabled: { backgroundColor: "#243046", opacity: 0.6 },
  saveBtnText: { color: "#fff", fontSize: 15, fontWeight: "600" },
});
