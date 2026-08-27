import React from "react";
import { fireEvent, render } from "@testing-library/react-native";
import { Linking } from "react-native";
import { CockpitScreen, COCKPIT_URL } from "../screens/CockpitScreen";

// react-native-webview is mocked in jest.setup.js as a plain View that
// forwards its props, so we can assert on the configuration the real
// WKWebView would receive.
describe("CockpitScreen", () => {
  it("points the web view at the tailnet Cockpit", () => {
    const r = render(<CockpitScreen />);
    const web = r.getByTestId("cockpit-webview");
    expect(web.props.source).toEqual({ uri: COCKPIT_URL });
    expect(COCKPIT_URL.startsWith("https://")).toBe(true);
  });

  it("configures the media props the Cockpit's voice control needs", () => {
    const r = render(<CockpitScreen />);
    const web = r.getByTestId("cockpit-webview");
    // Same-host grant + system prompt for anything else: iOS's own
    // permission machinery, no in-app permission UI.
    expect(web.props.mediaCapturePermissionGrantType).toBe(
      "grantIfSameHostElsePrompt",
    );
    expect(web.props.allowsInlineMediaPlayback).toBe(true);
    expect(web.props.mediaPlaybackRequiresUserAction).toBe(false);
  });

  it("enables pull-to-refresh and exposes a reload control", () => {
    const r = render(<CockpitScreen />);
    expect(r.getByTestId("cockpit-webview").props.pullToRefreshEnabled).toBe(
      true,
    );
    expect(r.getByTestId("cockpit-reload")).toBeTruthy();
  });

  it("shows a loading state until the page finishes loading", () => {
    const r = render(<CockpitScreen />);
    expect(r.getByTestId("cockpit-loading")).toBeTruthy();
    fireEvent(r.getByTestId("cockpit-webview"), "loadEnd");
    expect(r.queryByTestId("cockpit-loading")).toBeNull();
  });

  it("shows a reconnect panel instead of a blank view on load failure", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "A server with the specified hostname could not be found.", code: -1003 },
    });
    expect(r.getByTestId("cockpit-error")).toBeTruthy();
    expect(r.getByText("Can't reach the Cockpit")).toBeTruthy();
    expect(r.getByText(/Tailscale/)).toBeTruthy();
    expect(r.queryByTestId("cockpit-webview")).toBeNull();
  });

  it("shows the reconnect panel on an HTTP error too", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "httpError", {
      nativeEvent: { statusCode: 502, description: "Bad Gateway" },
    });
    expect(r.getByTestId("cockpit-error")).toBeTruthy();
  });

  it("retries the load from the reconnect panel", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "offline", code: -1009 },
    });
    fireEvent.press(r.getByTestId("cockpit-retry"));
    expect(r.queryByTestId("cockpit-error")).toBeNull();
    expect(r.getByTestId("cockpit-webview")).toBeTruthy();
  });

  it("keeps Cockpit navigation in the tab and hands other hosts to the browser", () => {
    const openURL = jest
      .spyOn(Linking, "openURL")
      .mockResolvedValue(undefined as never);
    const r = render(<CockpitScreen />);
    const shouldLoad =
      r.getByTestId("cockpit-webview").props.onShouldStartLoadWithRequest;

    expect(shouldLoad({ url: `${COCKPIT_URL}/decisions` })).toBe(true);
    expect(openURL).not.toHaveBeenCalled();

    expect(shouldLoad({ url: "https://github.com/idvorkin/igor2/pull/1" })).toBe(
      false,
    );
    expect(openURL).toHaveBeenCalledWith(
      "https://github.com/idvorkin/igor2/pull/1",
    );
    openURL.mockRestore();
  });

  it("stays mounted but hidden when another tab is active", () => {
    const r = render(<CockpitScreen visible={false} />);
    // Hidden from the accessibility tree (that's the point), so queries
    // have to opt in to hidden elements to see it at all.
    const screen = r.getByTestId("cockpit-screen", {
      includeHiddenElements: true,
    });
    expect(
      r.getByTestId("cockpit-webview", { includeHiddenElements: true }),
    ).toBeTruthy();
    const style = Array.isArray(screen.props.style)
      ? Object.assign({}, ...screen.props.style.filter(Boolean))
      : screen.props.style;
    expect(style.display).toBe("none");
  });
});
