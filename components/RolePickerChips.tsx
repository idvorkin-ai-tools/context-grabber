import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { ROLES, type RoleId } from "../lib/roles";
import { RoleAvatar } from "./RoleAvatar";

type Props = {
  selected: ReadonlySet<RoleId>;
  onToggle: (roleId: RoleId) => void;
  /** Optional heading text rendered above the chip strip. Pass null/undefined to omit. */
  heading?: string | null;
  /** Test id prefix for the chip elements; defaults to "role-pick". */
  testIDPrefix?: string;
};

export function RolePickerChips({
  selected,
  onToggle,
  heading = "Tag roles (optional)",
  testIDPrefix = "role-pick",
}: Props) {
  return (
    <View style={styles.container}>
      {heading && <Text style={styles.heading}>{heading}</Text>}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.row}
      >
        {ROLES.map((r) => {
          const isSelected = selected.has(r.id);
          return (
            <Pressable
              key={r.id}
              onPress={() => onToggle(r.id)}
              style={[
                styles.chip,
                isSelected && {
                  borderColor: r.color,
                  backgroundColor: hexWithAlpha(r.color, 0.18),
                },
              ]}
              testID={`${testIDPrefix}-${r.id}`}
              accessibilityState={{ selected: isSelected }}
              accessibilityLabel={`${isSelected ? "Untag" : "Tag"} ${r.name}`}
            >
              <RoleAvatar
                roleId={r.id}
                size={28}
                ringColor={isSelected ? r.color : "#2a2a40"}
              />
              <Text
                style={[
                  styles.chipLabel,
                  isSelected && { color: r.color },
                ]}
                numberOfLines={1}
              >
                {r.short}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
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
  container: {
    marginTop: 8,
  },
  heading: {
    color: "#888",
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 6,
  },
  row: {
    paddingVertical: 4,
    gap: 6,
  },
  chip: {
    width: 64,
    paddingVertical: 8,
    paddingHorizontal: 4,
    borderRadius: 10,
    backgroundColor: "#1a1f2e",
    borderWidth: 1,
    borderColor: "transparent",
    alignItems: "center",
    marginRight: 6,
  },
  chipLabel: {
    color: "#aaa",
    fontSize: 10,
    marginTop: 4,
    textAlign: "center",
  },
});
