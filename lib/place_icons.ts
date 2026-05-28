/** Centralized place-name → icon mapping. Match is case-insensitive substring.
 * Order matters: first match wins, so put more-specific patterns above
 * shorter ones. */

const ICON_RULES: Array<{ pattern: RegExp; icon: string }> = [
  { pattern: /\bhome\b/i, icon: "🏠" },
  { pattern: /\b(work|office)\b/i, icon: "💼" },
  { pattern: /\bgym\b/i, icon: "🏋️" },
  { pattern: /\b(cafe|coffee|café)\b/i, icon: "☕" },
  { pattern: /\b(school|university|college)\b/i, icon: "🎓" },
];

export function iconForPlace(name: string): string | null {
  for (const rule of ICON_RULES) {
    if (rule.pattern.test(name)) return rule.icon;
  }
  return null;
}
