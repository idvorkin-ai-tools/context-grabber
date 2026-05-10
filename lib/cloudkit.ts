import {
  configure,
  getAccountStatus,
  saveRecords,
  fetchRecord,
  type AccountStatus,
} from "expo-cloudkit";

const CONTAINER_ID = "iCloud.com.idvorkin.contextgrabber";

let configured = false;

export function configureCloudKit(): void {
  if (configured) return;
  configure(CONTAINER_ID);
  configured = true;
}

export async function cloudKitAccountStatus(): Promise<AccountStatus> {
  configureCloudKit();
  return getAccountStatus();
}

export type PingResult = {
  ok: true;
  recordName: string;
  echoedTimestamp: number;
  roundTripMs: number;
} | {
  ok: false;
  error: string;
};

/**
 * P0 spike: save a SpikeRecord with `now`, fetch it back, confirm round-trip.
 * Used by the About screen "Ping CloudKit" button.
 */
export async function pingCloudKit(): Promise<PingResult> {
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return { ok: false, error: `account status: ${status}` };
    }

    const now = Date.now();
    const start = now;
    const [saved] = await saveRecords([
      {
        recordType: "SpikeRecord",
        zoneName: "_defaultZone",
        fields: { now: { type: "number", value: now } },
      },
    ]);

    const fetched = await fetchRecord(
      "SpikeRecord",
      saved.recordName,
      "_defaultZone",
    );
    const echoed = fetched.fields.now?.value as number | undefined;
    if (typeof echoed !== "number" || echoed !== now) {
      return { ok: false, error: `echo mismatch: got ${echoed}, expected ${now}` };
    }

    return {
      ok: true,
      recordName: saved.recordName,
      echoedTimestamp: echoed,
      roundTripMs: Date.now() - start,
    };
  } catch (e: any) {
    return { ok: false, error: e?.message ?? String(e) };
  }
}
