/**
 * Tests for lib/roleMoments.ts pure helpers — specifically the source_ref
 * normalizer that maps a moment back to its journal entry id (or null).
 */

import { journalEntryIdFromMoment, type RoleMoment } from "../lib/roleMoments";

function moment(partial: Partial<RoleMoment>): RoleMoment {
  return {
    id: "m1",
    roleId: "tori",
    timestamp: 0,
    what: "",
    tag: null,
    source: "manual",
    sourceRef: null,
    ...partial,
  };
}

describe("journalEntryIdFromMoment", () => {
  it("returns the raw entry id for a card-tagged manual moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "manual", sourceRef: "entry-abc" }),
      ),
    ).toBe("entry-abc");
  });

  it("strips the journal: prefix from an auto-journal moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-journal", sourceRef: "journal:entry-xyz" }),
      ),
    ).toBe("entry-xyz");
  });

  it("strips the journal: prefix from an auto-grateful moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-grateful", sourceRef: "journal:g-1" }),
      ),
    ).toBe("g-1");
  });

  it("returns null for a workout moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-workout", sourceRef: "workout:12345" }),
      ),
    ).toBeNull();
  });

  it("returns null for a mindful moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-mindful", sourceRef: "mindful:2026-05-30T10:00:00Z" }),
      ),
    ).toBeNull();
  });

  it("returns null for a free-form manual tag with no source_ref", () => {
    expect(
      journalEntryIdFromMoment(moment({ source: "manual", sourceRef: null })),
    ).toBeNull();
  });

  it("returns null when an auto-detected source carries a bare ref", () => {
    // Defensive: auto sources should never resolve to a journal entry even
    // if their ref lacks a recognizable prefix.
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-workout", sourceRef: "somethingweird" }),
      ),
    ).toBeNull();
  });
});
