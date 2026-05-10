// Fixed list of affirmations carried over from Humane Tracker
// (humane-tracker/src/constants/affirmations.ts).
// The card picks one at random each open — rotation across all four is
// intentional, not a "last selected sticks" model. See spec
// 2026-05-10-affirmations-journal-design.md.

export type Affirmation = {
  title: string;
  subtitle: string;
};

export const AFFIRMATIONS: readonly Affirmation[] = [
  {
    title: "Do It Anyways",
    subtitle: "Deliberate. Disciplined. Daily.",
  },
  {
    title: "An Essentialist",
    subtitle: "Know Essential. Give Context. Prioritize Ruthlessly.",
  },
  {
    title: "A Class Act",
    subtitle: "First Understand. Appreciate. Isn't that Curious.",
  },
  {
    title: "Calm Like Water",
    subtitle: "Be Present. This too shall pass. Work the problem.",
  },
] as const;

// "Grateful" entries don't tie to one of the four; they live under their
// own bucket so journal grouping stays clean.
export const GRATEFUL_BUCKET = "Grateful" as const;

export const ALL_AFFIRMATION_TITLES: readonly string[] = [
  ...AFFIRMATIONS.map((a) => a.title),
  GRATEFUL_BUCKET,
];

/**
 * Pick a random affirmation index, biased away from `currentIndex` so the
 * same card never repeats on consecutive opens. With four affirmations
 * this is just `(rand() * 3 + 1) mod 4`-style, but the loop keeps the
 * code obvious.
 */
export function getRandomAffirmationIndex(currentIndex?: number): number {
  if (AFFIRMATIONS.length <= 1) return 0;
  let n: number;
  do {
    n = Math.floor(Math.random() * AFFIRMATIONS.length);
  } while (n === currentIndex);
  return n;
}
