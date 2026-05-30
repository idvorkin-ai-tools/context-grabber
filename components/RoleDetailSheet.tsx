import React, { useCallback, useEffect, useState } from "react";
import {
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import { getRole, type RoleId, type RoleWeekActivity } from "../lib/roles";
import {
  getMomentsForRole,
  journalEntryIdFromMoment,
  type RoleMoment,
  type RoleMomentSource,
} from "../lib/roleMoments";
import {
  getAudio,
  getEntriesByIds,
} from "../lib/journalDb";
import type { AudioRecording, JournalContext, JournalEntry } from "../lib/journal";
import { RoleAvatar } from "./RoleAvatar";
import { TagMomentSheet } from "./TagMomentSheet";
import { AffirmationCard } from "./AffirmationCard";
import { GratefulCard } from "./GratefulCard";
import { AudioPlayer } from "./AudioPlayer";

type Props = {
  visible: boolean;
  roleId: RoleId | null;
  activity: RoleWeekActivity | null;
  db: SQLite.SQLiteDatabase | null;
  onClose: () => void;
};

const RECENT_LIMIT = 20;

const SOURCE_LABEL: Record<RoleMomentSource, string> = {
  manual: "manual",
  "auto-workout": "workout",
  "auto-mindful": "mindful",
  "auto-grateful": "grateful",
  "auto-journal": "journal",
  "auto-place": "place",
};

/** Singular context label for a moment kicker (CONTEXT_LABEL is plural). */
const CONTEXT_KICKER: Record<JournalContext, string> = {
  opportunity: "Opportunity",
  didit: "Did-It",
  grateful: "Gratitude",
};

export function RoleDetailSheet({
  visible,
  roleId,
  activity,
  db,
  onClose,
}: Props) {
  const [moments, setMoments] = useState<RoleMoment[]>([]);
  const [entryMap, setEntryMap] = useState<Record<string, JournalEntry>>({});
  const [audioMap, setAudioMap] = useState<Record<string, AudioRecording>>({});
  const [tagSheetVisible, setTagSheetVisible] = useState(false);
  const [affirmCardVisible, setAffirmCardVisible] = useState(false);
  const [gratefulCardVisible, setGratefulCardVisible] = useState(false);
  const [eulogyExpanded, setEulogyExpanded] = useState(false);

  const role = roleId ? getRole(roleId) : null;

  const reload = useCallback(() => {
    if (!db || !roleId) {
      setMoments([]);
      setEntryMap({});
      setAudioMap({});
      return;
    }
    void (async () => {
      try {
        const rows = await getMomentsForRole(db, roleId, RECENT_LIMIT);
        setMoments(rows);
        // Resolve journal-backed moments so the row can show the actual
        // affirmation/gratitude content + voice, not just a label.
        const entryIds = Array.from(
          new Set(
            rows
              .map((m) => journalEntryIdFromMoment(m))
              .filter((id): id is string => id != null),
          ),
        );
        const entries = await getEntriesByIds(db, entryIds);
        const eMap: Record<string, JournalEntry> = {};
        for (const e of entries) eMap[e.id] = e;
        setEntryMap(eMap);
        const aMap: Record<string, AudioRecording> = {};
        for (const e of entries) {
          if (e.audioRecordingId && !aMap[e.audioRecordingId]) {
            const a = await getAudio(db, e.audioRecordingId);
            if (a) aMap[e.audioRecordingId] = a;
          }
        }
        setAudioMap(aMap);
      } catch {
        // Tolerate missing table — sheet still renders with empty list.
        setMoments([]);
        setEntryMap({});
        setAudioMap({});
      }
    })();
  }, [db, roleId]);

  useEffect(() => {
    if (visible) reload();
  }, [visible, reload]);

  // Reset expander state whenever the sheet opens with a different role.
  useEffect(() => {
    if (visible) setEulogyExpanded(false);
  }, [visible, roleId]);

  if (!role) {
    return (
      <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
        <View style={styles.backdrop}>
          <View style={styles.sheet} />
        </View>
      </Modal>
    );
  }

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <View style={styles.header}>
            <View style={styles.headerLeft}>
              <RoleAvatar roleId={role.id} size={44} ringColor={role.color} />
              <View style={styles.headerText}>
                <Text style={styles.title}>{role.name}</Text>
                <Text style={styles.subtitle}>Role · 7-day view</Text>
              </View>
            </View>
            <TouchableOpacity onPress={onClose} testID="role-detail-close">
              <Text style={styles.close}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView
            style={styles.scroll}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={false}
          >
            <View style={[styles.passage, { borderLeftColor: role.color }]}>
              <Text style={styles.passageText}>{role.eulogyPassage}</Text>
              {eulogyExpanded && (
                <>
                  {role.eulogyFull && (
                    <Text style={[styles.passageText, styles.passageFull]}>
                      {role.eulogyFull}
                    </Text>
                  )}
                  {role.eulogyMarkers.length > 0 && (
                    <View style={styles.markerRow}>
                      {role.eulogyMarkers.map((marker) => (
                        <View
                          key={marker}
                          style={[
                            styles.markerChip,
                            { borderColor: hexWithAlpha(role.color, 0.5) },
                          ]}
                        >
                          <Text style={styles.markerText}>{marker}</Text>
                        </View>
                      ))}
                    </View>
                  )}
                </>
              )}
              <TouchableOpacity
                onPress={() => setEulogyExpanded((v) => !v)}
                style={styles.expandBtn}
                testID="role-eulogy-expand"
                accessibilityLabel={
                  eulogyExpanded ? "Hide eulogy details" : "Show full eulogy"
                }
              >
                <Text style={[styles.expandBtnText, { color: role.color }]}>
                  {eulogyExpanded ? "Show less ▴" : "Show more ▾"}
                </Text>
              </TouchableOpacity>
            </View>

            {activity && (
              <View style={styles.activityCard}>
                <View style={styles.activityHead}>
                  <Text style={styles.activityHeading}>This week</Text>
                  {activity.attention.flagged && activity.attention.reason && (
                    <View
                      style={[
                        styles.attentionChip,
                        { borderColor: hexWithAlpha(role.color, 0.5) },
                      ]}
                    >
                      <Text style={[styles.attentionChipText, { color: role.color }]}>
                        {activity.attention.reason}
                      </Text>
                    </View>
                  )}
                </View>
                <View style={styles.scoreRow}>
                  <Text style={[styles.scoreValue, { color: role.color }]}>
                    {activity.score}
                  </Text>
                  <Text style={styles.scoreUnit}>/ 100</Text>
                </View>
                <Text style={styles.activityLine}>{activity.activityLine}</Text>
              </View>
            )}

            <TouchableOpacity
              onPress={() => setAffirmCardVisible(true)}
              style={[styles.createBtn, { backgroundColor: role.color }]}
              testID="role-detail-log-affirmation"
            >
              <Text style={styles.createBtnText}>
                ✎  Log an affirmation as {role.short}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => setGratefulCardVisible(true)}
              style={[styles.createBtnOutline, { borderColor: role.color }]}
              testID="role-detail-write-gratitude"
            >
              <Text style={[styles.createBtnOutlineText, { color: role.color }]}>
                ♡  Write a gratitude as {role.short}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => setTagSheetVisible(true)}
              style={styles.tagBtn}
              testID="role-detail-tag-moment"
            >
              <Text style={styles.tagBtnText}>+ Tag a moment</Text>
            </TouchableOpacity>

            <Text style={styles.sectionHeading}>Recent moments</Text>
            {moments.length === 0 ? (
              <View style={styles.empty}>
                <Text style={styles.emptyText}>
                  No moments logged yet for {role.short}. Tag your first one.
                </Text>
              </View>
            ) : (
              moments.map((m) => {
                const entryId = journalEntryIdFromMoment(m);
                const entry = entryId ? entryMap[entryId] : undefined;
                const audio = entry?.audioRecordingId
                  ? audioMap[entry.audioRecordingId]
                  : undefined;
                const kicker =
                  entry && entry.context !== "grateful"
                    ? `${entry.affirmationTitle} · ${CONTEXT_KICKER[entry.context]}`
                    : null;
                return (
                  <View key={m.id} style={styles.momentRow} testID={`role-moment-${m.id}`}>
                    <View style={[styles.momentBar, { backgroundColor: role.color }]} />
                    <View style={styles.momentBody}>
                      {kicker && <Text style={styles.momentKicker}>{kicker}</Text>}
                      {/* Journal-backed moments show the entry's real words +
                          voice; everything else shows its one-line label. */}
                      {entry ? (
                        <>
                          {entry.text ? (
                            <Text style={styles.momentWhat}>{entry.text}</Text>
                          ) : null}
                          {entry.audioRecordingId && audio && (
                            <View style={{ marginTop: entry.text ? 8 : 2 }}>
                              <AudioPlayer
                                recordingId={entry.audioRecordingId}
                                durationMs={audio.durationMs}
                                db={db}
                              />
                            </View>
                          )}
                          {entry.audioRecordingId && !audio && (
                            <Text style={styles.momentPending}>
                              voice note (pending sync)
                            </Text>
                          )}
                        </>
                      ) : (
                        <Text style={styles.momentWhat} numberOfLines={2}>
                          {m.what}
                        </Text>
                      )}
                      <View style={styles.momentMeta}>
                        <Text style={styles.momentTime}>
                          {formatTimeSince(m.timestamp)}
                        </Text>
                        <View style={styles.dot} />
                        <Text style={styles.momentSource}>
                          {SOURCE_LABEL[m.source] ?? m.source}
                        </Text>
                        {m.tag && (
                          <>
                            <View style={styles.dot} />
                            <Text style={styles.momentTag}>#{m.tag}</Text>
                          </>
                        )}
                      </View>
                    </View>
                  </View>
                );
              })
            )}
          </ScrollView>
        </View>
      </View>

      <TagMomentSheet
        visible={tagSheetVisible}
        onClose={() => setTagSheetVisible(false)}
        db={db}
        initialRoleId={role.id}
        onSaved={reload}
      />
      <AffirmationCard
        visible={affirmCardVisible}
        onClose={() => {
          setAffirmCardVisible(false);
          reload();
        }}
        db={db}
        initialRoleIds={[role.id]}
      />
      <GratefulCard
        visible={gratefulCardVisible}
        onClose={() => {
          setGratefulCardVisible(false);
          reload();
        }}
        db={db}
        initialRoleIds={[role.id]}
      />
    </Modal>
  );
}

function formatTimeSince(ts: number): string {
  const diffMs = Date.now() - ts;
  if (diffMs < 0) return "just now";
  const min = Math.round(diffMs / 60000);
  if (min < 1) return "just now";
  if (min < 60) return `${min}m ago`;
  const hr = Math.round(diffMs / 3600000);
  if (hr < 24) return `${hr}h ago`;
  const days = Math.round(diffMs / 86400000);
  if (days < 7) return `${days}d ago`;
  const wk = Math.round(days / 7);
  if (wk < 5) return `${wk}w ago`;
  const d = new Date(ts);
  return d.toLocaleDateString();
}

function hexWithAlpha(hex: string, alpha: number): string {
  const m = hex.match(/^#([0-9a-fA-F]{6})$/);
  if (!m) return hex;
  const a = Math.round(Math.max(0, Math.min(1, alpha)) * 255)
    .toString(16)
    .padStart(2, "0");
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
    maxHeight: "88%",
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
    marginBottom: 8,
  },
  headerLeft: { flexDirection: "row", alignItems: "center", flex: 1 },
  headerText: { marginLeft: 12, flex: 1 },
  title: { color: "#e0e0e0", fontSize: 18, fontWeight: "700" },
  subtitle: { color: "#888", fontSize: 12, marginTop: 2 },
  close: { color: "#888", fontSize: 20, paddingHorizontal: 8 },
  scroll: { maxHeight: "100%" },
  scrollContent: { paddingBottom: 16 },
  passage: {
    borderLeftWidth: 3,
    paddingLeft: 12,
    paddingVertical: 4,
    marginTop: 8,
    marginBottom: 14,
  },
  passageText: {
    color: "#d6d6d6",
    fontSize: 14,
    lineHeight: 20,
    fontStyle: "italic",
  },
  passageFull: {
    marginTop: 10,
    fontStyle: "normal",
    color: "#bbb",
    fontSize: 13,
    lineHeight: 19,
  },
  markerRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    marginTop: 10,
    gap: 6,
  },
  markerChip: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
  },
  markerText: {
    color: "#d0d0d0",
    fontSize: 11,
    fontWeight: "500",
  },
  expandBtn: {
    marginTop: 8,
    alignSelf: "flex-start",
    paddingVertical: 4,
  },
  expandBtnText: {
    fontSize: 12,
    fontWeight: "700",
  },
  activityCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 14,
    marginBottom: 14,
  },
  activityHead: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 4,
  },
  activityHeading: {
    color: "#4cc9f0",
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  attentionChip: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
  },
  attentionChipText: { fontSize: 11, fontWeight: "600" },
  scoreRow: { flexDirection: "row", alignItems: "baseline", marginTop: 6 },
  scoreValue: {
    fontSize: 30,
    fontWeight: "700",
    fontVariant: ["tabular-nums"],
  },
  scoreUnit: {
    color: "#666",
    fontSize: 12,
    marginLeft: 4,
    fontVariant: ["tabular-nums"],
  },
  activityLine: { color: "#bbb", fontSize: 13, marginTop: 4 },
  createBtn: {
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: "center",
    marginBottom: 9,
  },
  createBtnText: { color: "#0e1116", fontSize: 15, fontWeight: "700" },
  createBtnOutline: {
    borderRadius: 12,
    paddingVertical: 13,
    alignItems: "center",
    borderWidth: 1.5,
    marginBottom: 9,
  },
  createBtnOutlineText: { fontSize: 15, fontWeight: "700" },
  tagBtn: {
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: "center",
    borderWidth: 1,
    borderColor: "#2f3a55",
    marginBottom: 18,
  },
  tagBtnText: { color: "#aeb6c6", fontSize: 14, fontWeight: "600" },
  sectionHeading: {
    color: "#888",
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 8,
  },
  empty: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderRadius: 10,
    padding: 14,
  },
  emptyText: { color: "#666", fontSize: 12, lineHeight: 18 },
  momentRow: {
    flexDirection: "row",
    backgroundColor: "#16213e",
    borderRadius: 10,
    padding: 12,
    marginBottom: 6,
  },
  momentBar: { width: 3, borderRadius: 1.5, marginRight: 10 },
  momentBody: { flex: 1 },
  momentKicker: {
    color: "#9aa3b2",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 0.4,
    textTransform: "uppercase",
    marginBottom: 3,
  },
  momentPending: {
    color: "#666",
    fontSize: 12,
    fontStyle: "italic",
    marginTop: 4,
  },
  momentWhat: { color: "#e0e0e0", fontSize: 14, lineHeight: 18 },
  momentMeta: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 4,
    flexWrap: "wrap",
  },
  momentTime: { color: "#888", fontSize: 11, fontVariant: ["tabular-nums"] },
  momentSource: { color: "#888", fontSize: 11 },
  momentTag: { color: "#4cc9f0", fontSize: 11 },
  dot: {
    width: 3,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: "#444",
    marginHorizontal: 6,
  },
});
