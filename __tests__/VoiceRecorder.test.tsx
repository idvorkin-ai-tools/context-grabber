import React from "react";
import { render } from "@testing-library/react-native";
import { VoiceRecorder } from "../components/VoiceRecorder";

// expo-audio is mocked in jest.setup.js with isRecording: false, so the
// recorder renders in its idle state.
describe("VoiceRecorder", () => {
  it("renders a compact mic toggle when compact", () => {
    const result = render(
      <VoiceRecorder compact onRecorded={() => {}} />,
    );
    const btn = result.getByTestId("voice-record-toggle");
    expect(btn).toBeTruthy();
    expect(result.getByText("🎤")).toBeTruthy();
  });

  it("renders the full-width Record pill by default", () => {
    const result = render(<VoiceRecorder onRecorded={() => {}} />);
    expect(result.getByTestId("voice-record-toggle")).toBeTruthy();
    expect(result.getByText("●  Record")).toBeTruthy();
  });
});
