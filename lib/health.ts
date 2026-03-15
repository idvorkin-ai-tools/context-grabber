export type HealthData = {
  steps: number | null;
  heartRate: number | null;
  sleepHours: number | null;
  activeEnergy: number | null;
  walkingDistance: number | null;
  // Optional fields from spec 1 — may not exist yet
  bedtime?: string | null;
  wakeTime?: string | null;
  weight?: number | null;
  meditationMinutes?: number | null;
};
