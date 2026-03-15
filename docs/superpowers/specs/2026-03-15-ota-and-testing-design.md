# OTA Updates + Testing Infrastructure

## Summary

Add over-the-air (OTA) JS bundle updates via `expo-updates` so the app can be updated without redeploying through Xcode. Add Jest-based unit testing for data logic.

## Goals

- Enable OTA updates for JS bundle changes (no Xcode rebuild needed)
- Reduce pain of 7-day free Apple ID expiry — native shell stays, JS updates push OTA
- Add unit tests for data transformation and business logic
- Establish test infrastructure for future development

## Non-Goals

- Component/UI testing (React Native Testing Library) — overkill for a single-screen app
- E2E testing — requires physical device with HealthKit
- CI/CD pipeline — manual `expo publish` is fine for now
- EAS Build — free tier works, but not required for OTA

## OTA Updates

### Mechanism

`expo-updates` checks for JS bundle updates on app launch. When a new bundle is available, it downloads in the background and applies on next cold start.

**How it works**:
1. Developer runs `expo publish` (or `eas update`) from the project
2. Expo hosts the updated JS bundle
3. On next app launch, the app checks for updates and downloads if available
4. New bundle applies on the following cold start

**Limitations**:
- Only JS/asset changes — native code changes (new permissions, new native modules) still require Xcode rebuild
- Free Expo account has update limits but sufficient for personal use
- First launch after install always uses embedded bundle

### Configuration

**Install**: `npx expo install expo-updates`

**app.json additions**:
```json
{
  "updates": {
    "enabled": true,
    "checkAutomatically": "ON_LAUNCH",
    "fallbackToCacheTimeout": 5000
  },
  "runtimeVersion": {
    "policy": "appVersion"
  }
}
```

**Runtime version policy**: `appVersion` ties the OTA bundle to the app version in app.json. Bump the version when native changes require a rebuild.

### File Changes

- `app.json` — updates config, runtimeVersion
- `package.json` — expo-updates dependency (added by `npx expo install`)

## Testing

### Framework

Jest (included with Expo) + TypeScript.

### What to Test

Unit tests for pure data logic extracted from App.tsx:

- **Sleep extraction**: bedtime/wake-time derivation from sleep samples (sorting, edge cases)
- **Health data mapping**: HealthKit query results → HealthData shape (null handling, rounding)
- **Location history pruning**: retention logic (prune by days, edge cases)
- **Export shape**: snapshot assembly produces valid ContextSnapshot

### Structure

```
__tests__/
  health.test.ts      — sleep extraction, health data mapping
  location.test.ts    — pruning logic, storage helpers
  snapshot.test.ts    — export shape assembly
```

### Approach

Extract pure functions from App.tsx where needed to make them testable. These functions take data in and return data out — no React, no HealthKit, no SQLite calls.

For example:
```typescript
// Extractable pure functions:
function extractSleepDetails(samples: SleepSample[]): { bedtime: string | null; wakeTime: string | null }
function buildHealthData(results: PromiseSettledResult<any>[]): HealthData
function shouldPrune(timestamp: number, retentionDays: number, now: number): boolean
```

Mock HealthKit and SQLite only at the boundary — the pure logic functions don't need mocks.

### Setup

```bash
npm install --save-dev jest @types/jest ts-jest
```

**jest.config.js**:
```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
};
```

**package.json script**:
```json
{
  "test": "jest"
}
```

### File Changes

- `jest.config.js` — test configuration
- `package.json` — test script, dev dependencies
- `__tests__/*.test.ts` — test files
- `App.tsx` — extract pure functions for testability (export them)
