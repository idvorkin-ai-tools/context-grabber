import React from "react";
import { render, waitFor } from "@testing-library/react-native";
import { JournalRecentList } from "../components/JournalRecentList";

describe("JournalRecentList", () => {
  it("renders the empty state when no entries are in the window", async () => {
    const result = render(<JournalRecentList db={null} windowHours={24} />);
    await waitFor(() =>
      expect(result.getByTestId("journal-recent-empty")).toBeTruthy(),
    );
  });

  it("shows the heading", () => {
    const result = render(
      <JournalRecentList db={null} windowHours={24} heading="Recent (24h)" />,
    );
    expect(result.getByText("Recent (24h)")).toBeTruthy();
  });
});
