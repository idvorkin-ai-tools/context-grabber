// Minimal UUID v4 — Math.random is fine here because IDs are namespaced
// per-user (single-user app), per-CloudKit-zone, and we don't depend on
// cryptographic unpredictability. Avoids pulling in expo-crypto for a
// 30-line module's worth of need.
//
// Format: 8-4-4-4-12 hex digits, version 4, variant 1.

export function uuidV4(): string {
  // Generate 16 random bytes via Math.random.
  const bytes = new Uint8Array(16);
  for (let i = 0; i < 16; i++) {
    bytes[i] = Math.floor(Math.random() * 256);
  }
  // Set version (4) and variant (10).
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex: string[] = [];
  for (let i = 0; i < 16; i++) {
    hex.push(bytes[i].toString(16).padStart(2, "0"));
  }
  return [
    hex.slice(0, 4).join(""),
    hex.slice(4, 6).join(""),
    hex.slice(6, 8).join(""),
    hex.slice(8, 10).join(""),
    hex.slice(10, 16).join(""),
  ].join("-");
}
