import { StatusBar } from "expo-status-bar";
import { useState, useEffect, useCallback } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  TouchableOpacity,
  Share,
  Platform,
  Switch,
  TextInput,
  AppState,
} from "react-native";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as SQLite from "expo-sqlite";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, type HealthData } from "./lib/health";
import { pruneThreshold } from "./lib/location";

// --- Constants ---

const LOCATION_TASK_NAME = "background-location-task";

const DB_NAME = "context-grabber.db";

type LocationHistoryItem = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  timestamp: number;
};

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type ContextSnapshot = {
  timestamp: string;
  health: HealthData;
  location: LocationData;
  locationHistory: LocationHistoryItem[];
};

const QTI = {
  stepCount: "HKQuantityTypeIdentifierStepCount" as QuantityTypeIdentifier,
  heartRate: "HKQuantityTypeIdentifierHeartRate" as QuantityTypeIdentifier,
  activeEnergy:
    "HKQuantityTypeIdentifierActiveEnergyBurned" as QuantityTypeIdentifier,
  distance:
    "HKQuantityTypeIdentifierDistanceWalkingRunning" as QuantityTypeIdentifier,
  bodyMass: "HKQuantityTypeIdentifierBodyMass" as QuantityTypeIdentifier,
};

const CTI = {
  sleep: "HKCategoryTypeIdentifierSleepAnalysis" as CategoryTypeIdentifier,
  mindfulSession:
    "HKCategoryTypeIdentifierMindfulSession" as CategoryTypeIdentifier,
};

// --- SQLite helpers (module-level for use by background task) ---

async function openDB(): Promise<SQLite.SQLiteDatabase> {
  return SQLite.openDatabaseAsync(DB_NAME);
}

async function initDB(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy REAL,
      timestamp INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp);
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '1');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
  `);
}

async function getSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  defaultValue: string,
): Promise<string> {
  const row = await db.getFirstAsync<{ value: string }>(
    "SELECT value FROM settings WHERE key = ?",
    [key],
  );
  return row?.value ?? defaultValue;
}

async function setSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  value: string,
): Promise<void> {
  await db.runAsync(
    "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
    [key, value],
  );
}

async function insertLocation(
  db: SQLite.SQLiteDatabase,
  latitude: number,
  longitude: number,
  accuracy: number | null,
  timestamp: number,
): Promise<void> {
  await db.runAsync(
    "INSERT INTO locations (latitude, longitude, accuracy, timestamp) VALUES (?, ?, ?, ?)",
    [latitude, longitude, accuracy, timestamp],
  );
}

async function pruneLocations(
  db: SQLite.SQLiteDatabase,
  retentionDays: number,
): Promise<void> {
  const threshold = pruneThreshold(retentionDays, Date.now());
  await db.runAsync("DELETE FROM locations WHERE timestamp < ?", [threshold]);
}

async function getLocationCount(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ count: number }>(
    "SELECT COUNT(*) as count FROM locations",
  );
  return row?.count ?? 0;
}

async function getLocationHistory(
  db: SQLite.SQLiteDatabase,
): Promise<LocationHistoryItem[]> {
  const rows = await db.getAllAsync<LocationHistoryItem>(
    "SELECT latitude, longitude, accuracy, timestamp FROM locations ORDER BY timestamp ASC",
  );
  return rows;
}

// --- Background Location Task (MUST be at module scope) ---

TaskManager.defineTask(LOCATION_TASK_NAME, async ({ data, error }) => {
  if (error) {
    console.error("Background location task error:", error.message);
    return;
  }
  if (data) {
    const { locations } = data as { locations: Location.LocationObject[] };
    try {
      const db = await openDB();
      for (const loc of locations) {
        await insertLocation(
          db,
          loc.coords.latitude,
          loc.coords.longitude,
          loc.coords.accuracy,
          loc.timestamp,
        );
      }
    } catch (e) {
      console.error("Failed to store background location:", e);
    }
  }
});

// --- App Component ---

export default function App() {
  const [snapshot, setSnapshot] = useState<ContextSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [trackingEnabled, setTrackingEnabled] = useState(false);
  const [retentionDays, setRetentionDays] = useState("30");
  const [locationCount, setLocationCount] = useState(0);
  const [db, setDb] = useState<SQLite.SQLiteDatabase | null>(null);

  // Initialize database on mount
  useEffect(() => {
    (async () => {
      try {
        const database = await openDB();
        await initDB(database);
        setDb(database);

        const enabled = await getSetting(database, "tracking_enabled", "false");
        setTrackingEnabled(enabled === "true");

        const days = await getSetting(database, "retention_days", "30");
        setRetentionDays(days);

        const count = await getLocationCount(database);
        setLocationCount(count);

        // Prune on startup
        await pruneLocations(database, parseInt(days, 10) || 30);
        const countAfterPrune = await getLocationCount(database);
        setLocationCount(countAfterPrune);
      } catch (e) {
        console.error("DB init error:", e);
      }
    })();
  }, []);

  // Prune on app foreground
  useEffect(() => {
    const subscription = AppState.addEventListener("change", async (state) => {
      if (state === "active" && db) {
        try {
          const days = parseInt(
            await getSetting(db, "retention_days", "30"),
            10,
          ) || 30;
          await pruneLocations(db, days);
          const count = await getLocationCount(db);
          setLocationCount(count);
        } catch (e) {
          console.error("Prune on foreground error:", e);
        }
      }
    });
    return () => subscription.remove();
  }, [db]);

  const startTracking = useCallback(async () => {
    try {
      const { status: fgStatus } =
        await Location.requestForegroundPermissionsAsync();
      if (fgStatus !== "granted") {
        setError("Foreground location permission denied");
        return false;
      }

      const { status: bgStatus } =
        await Location.requestBackgroundPermissionsAsync();
      if (bgStatus !== "granted") {
        setError("Background location permission denied");
        return false;
      }

      await Location.startLocationUpdatesAsync(LOCATION_TASK_NAME, {
        accuracy: Location.Accuracy.Balanced,
        activityType: Location.ActivityType.Other,
        deferredUpdatesInterval: 0,
        deferredUpdatesDistance: 0,
        showsBackgroundLocationIndicator: true,
      });

      return true;
    } catch (e: any) {
      setError(e.message ?? "Failed to start tracking");
      return false;
    }
  }, []);

  const stopTracking = useCallback(async () => {
    try {
      const hasStarted =
        await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK_NAME);
      if (hasStarted) {
        await Location.stopLocationUpdatesAsync(LOCATION_TASK_NAME);
      }
    } catch (e) {
      console.error("Failed to stop tracking:", e);
    }
  }, []);

  async function handleTrackingToggle(enabled: boolean) {
    if (!db) return;

    if (enabled) {
      const started = await startTracking();
      if (!started) return;
    } else {
      await stopTracking();
    }

    setTrackingEnabled(enabled);
    await setSetting(db, "tracking_enabled", enabled ? "true" : "false");
  }

  async function handleRetentionChange(text: string) {
    setRetentionDays(text);
    if (!db) return;

    const days = parseInt(text, 10);
    if (!isNaN(days) && days >= 0) {
      await setSetting(db, "retention_days", String(days));
      await pruneLocations(db, days);
      const count = await getLocationCount(db);
      setLocationCount(count);
    }
  }

  async function grabHealthData(): Promise<HealthData> {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const dateFilter = {
      date: { startDate: startOfDay, endDate: now },
    };
    const sleepDateFilter = {
      date: { startDate: yesterday, endDate: now },
    };

    const results = await Promise.allSettled([
      HealthKit.queryStatisticsForQuantity(QTI.stepCount, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.getMostRecentQuantitySample(QTI.heartRate),
      HealthKit.queryStatisticsForQuantity(
        QTI.activeEnergy,
        ["cumulativeSum"],
        { filter: dateFilter },
      ),
      HealthKit.queryStatisticsForQuantity(QTI.distance, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: sleepDateFilter,
      }),
      HealthKit.getMostRecentQuantitySample(QTI.bodyMass),
      HealthKit.queryCategorySamples(CTI.mindfulSession, {
        limit: 0,
        filter: dateFilter,
      }),
    ]);

    return buildHealthData(results as any);
  }

  async function grabLocation(): Promise<LocationData> {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== "granted") {
      return null;
    }
    const loc = await Location.getCurrentPositionAsync({});
    return {
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
      timestamp: loc.timestamp,
    };
  }

  async function grabContext() {
    setLoading(true);
    setError(null);
    try {
      await HealthKit.requestAuthorization({
        toRead: [
          QTI.stepCount,
          QTI.heartRate,
          QTI.activeEnergy,
          QTI.distance,
          QTI.bodyMass,
          CTI.sleep,
          CTI.mindfulSession,
        ],
      });

      const [health, location] = await Promise.all([
        grabHealthData(),
        grabLocation(),
      ]);

      // Fetch location history from SQLite
      let locationHistory: LocationHistoryItem[] = [];
      if (db) {
        try {
          locationHistory = await getLocationHistory(db);
          setLocationCount(locationHistory.length);
        } catch (e) {
          console.error("Failed to fetch location history:", e);
        }
      }

      const result: ContextSnapshot = {
        timestamp: new Date().toISOString(),
        health,
        location,
        locationHistory,
      };
      setSnapshot(result);
    } catch (e: any) {
      setError(e.message ?? "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  async function shareSnapshot() {
    if (!snapshot) return;
    const json = JSON.stringify(snapshot, null, 2);
    await Share.share({
      message: json,
      title: "Context Grabber Snapshot",
    });
  }

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <Text style={styles.title}>Context Grabber</Text>
        <Text style={styles.subtitle}>
          Grab your iPhone context for your AI life coach
        </Text>
      </View>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
      >
        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {/* Tracking Settings */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Location Tracking</Text>
          <View style={styles.settingRow}>
            <Text style={styles.dataRow}>Background Tracking</Text>
            <Switch
              value={trackingEnabled}
              onValueChange={handleTrackingToggle}
              trackColor={{ false: "#555", true: "#4361ee" }}
              thumbColor="#fff"
            />
          </View>
          <View style={styles.settingRow}>
            <Text style={styles.dataRow}>Retention (days)</Text>
            <TextInput
              style={styles.retentionInput}
              value={retentionDays}
              onChangeText={handleRetentionChange}
              keyboardType="number-pad"
              maxLength={4}
              selectTextOnFocus
            />
          </View>
          <Text style={styles.locationCount}>
            {locationCount} location{locationCount !== 1 ? "s" : ""} tracked
          </Text>
        </View>

        {snapshot && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Health</Text>
            <Text style={styles.dataRow}>
              Steps: {snapshot.health.steps ?? "\u2014"}
            </Text>
            <Text style={styles.dataRow}>
              Heart Rate: {snapshot.health.heartRate ?? "\u2014"} bpm
            </Text>
            <Text style={styles.dataRow}>
              Sleep: {snapshot.health.sleepHours ?? "\u2014"} hrs
            </Text>
            <Text style={styles.dataRow}>
              Bedtime: {snapshot.health.bedtime ?? "\u2014"}
            </Text>
            <Text style={styles.dataRow}>
              Wake: {snapshot.health.wakeTime ?? "\u2014"}
            </Text>
            <Text style={styles.dataRow}>
              Active Energy: {snapshot.health.activeEnergy ?? "\u2014"} kcal
            </Text>
            <Text style={styles.dataRow}>
              Distance: {snapshot.health.walkingDistance ?? "\u2014"} km
            </Text>
            <Text style={styles.dataRow}>
              Weight: {snapshot.health.weight ?? "\u2014"} kg
            </Text>
            <Text style={styles.dataRow}>
              Meditation: {snapshot.health.meditationMinutes ?? "\u2014"} min
            </Text>

            <Text style={[styles.cardTitle, { marginTop: 16 }]}>Location</Text>
            {snapshot.location ? (
              <Text style={styles.dataRow}>
                {snapshot.location.latitude.toFixed(4)},{" "}
                {snapshot.location.longitude.toFixed(4)}
              </Text>
            ) : (
              <Text style={styles.dataRow}>Unavailable</Text>
            )}

            {snapshot.locationHistory.length > 0 && (
              <>
                <Text style={[styles.cardTitle, { marginTop: 16 }]}>
                  Location History
                </Text>
                <Text style={styles.dataRow}>
                  {snapshot.locationHistory.length} point
                  {snapshot.locationHistory.length !== 1 ? "s" : ""} in trail
                </Text>
              </>
            )}

            <Text style={styles.timestamp}>{snapshot.timestamp}</Text>
          </View>
        )}
      </ScrollView>

      <View style={styles.buttons}>
        <TouchableOpacity
          style={[styles.button, styles.grabButton]}
          onPress={grabContext}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? "Grabbing..." : "Grab Context"}
          </Text>
        </TouchableOpacity>

        {snapshot && (
          <TouchableOpacity
            style={[styles.button, styles.shareButton]}
            onPress={shareSnapshot}
          >
            <Text style={styles.buttonText}>Share JSON</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#1a1a2e",
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  subtitle: {
    fontSize: 14,
    color: "#888",
    marginTop: 4,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  contentInner: {
    paddingBottom: 20,
  },
  card: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#4cc9f0",
    marginBottom: 8,
  },
  dataRow: {
    fontSize: 16,
    color: "#ccc",
    marginBottom: 4,
  },
  timestamp: {
    fontSize: 12,
    color: "#666",
    marginTop: 12,
    textAlign: "right",
  },
  errorBox: {
    backgroundColor: "#3d1f1f",
    borderRadius: 8,
    padding: 12,
    marginTop: 12,
  },
  errorText: {
    color: "#ff6b6b",
    fontSize: 14,
  },
  buttons: {
    paddingHorizontal: 20,
    paddingBottom: Platform.OS === "ios" ? 40 : 20,
    gap: 10,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  grabButton: {
    backgroundColor: "#4361ee",
  },
  shareButton: {
    backgroundColor: "#2d6a4f",
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  settingRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  retentionInput: {
    backgroundColor: "#1a1a2e",
    color: "#fff",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    fontSize: 16,
    width: 60,
    textAlign: "center",
    borderWidth: 1,
    borderColor: "#333",
  },
  locationCount: {
    fontSize: 13,
    color: "#888",
    marginTop: 4,
  },
});
