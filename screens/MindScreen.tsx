import React from "react";
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import { JournalRecentList } from "../components/JournalRecentList";
import { MeditationFlatlineCard } from "../components/MeditationFlatlineCard";
import { MoodReportCard } from "../components/MoodReportCard";
import type { DailyValue } from "../lib/weekly";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  todayMeditationMinutes: number | null;
  weeklyMeditation: DailyValue[] | null;
  onOpenAffirmation: () => void;
  onOpenGrateful: () => void;
  onOpenJournal: () => void;
  onMoodSaved?: () => void;
  /** Bumped when a journal entry is logged so the recent list refreshes. */
  journalReloadKey?: number;
};

export function MindScreen({
  db,
  todayMeditationMinutes,
  weeklyMeditation,
  onOpenAffirmation,
  onOpenGrateful,
  onOpenJournal,
  onMoodSaved,
  journalReloadKey,
}: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Mind</Text>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        <MoodReportCard db={db} onSaved={onMoodSaved} />

        <MeditationFlatlineCard
          todayMinutes={todayMeditationMinutes}
          weekly={weeklyMeditation}
        />

        <Text style={styles.sectionHeading}>Reflect</Text>
        <View style={styles.reflectGrid}>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnAffirm]}
            onPress={onOpenAffirmation}
            testID="mind-affirm"
          >
            <Text style={styles.reflectBtnText}>🎯 Affirm</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnGrateful]}
            onPress={onOpenGrateful}
            testID="mind-grateful"
          >
            <Text style={styles.reflectBtnText}>🙏 Grateful</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnJournal]}
            onPress={onOpenJournal}
            testID="mind-journal"
          >
            <Text style={styles.reflectBtnText}>📖 Journal</Text>
          </TouchableOpacity>
        </View>

        <JournalRecentList
          db={db}
          windowHours={24}
          heading="Recent (24h)"
          reloadKey={journalReloadKey}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  scroll: { paddingHorizontal: 20, paddingBottom: 20 },
  sectionHeading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  reflectGrid: {
    flexDirection: "row",
    gap: 8,
    marginBottom: 16,
  },
  reflectBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: "center",
  },
  btnAffirm: { backgroundColor: "#1a2a3a" },
  btnGrateful: { backgroundColor: "#2a1f1a" },
  btnJournal: { backgroundColor: "#1a1a1a" },
  reflectBtnText: { color: "#fff", fontSize: 14, fontWeight: "600" },
});
