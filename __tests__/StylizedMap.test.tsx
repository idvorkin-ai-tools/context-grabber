import React from "react";
import { render } from "@testing-library/react-native";
import { StylizedMap, type PathPoint } from "../components/StylizedMap";

describe("StylizedMap", () => {
  const baseProps = {
    currentLocation: {
      latitude: 47.61,
      longitude: -122.33,
      timestamp: Date.now(),
    },
    knownPlaces: [
      {
        id: 1,
        name: "Home",
        latitude: 47.6419,
        longitude: -122.3045,
        radiusMeters: 100,
      },
    ],
  };

  it("renders pins without a path prop", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
    expect(result.queryByTestId("map-path-polyline")).toBeNull();
  });

  it("renders no polyline when path has < 2 points", () => {
    const path: PathPoint[] = [{ lat: 47.6, lon: -122.33 }];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    expect(result.queryByTestId("map-path-polyline")).toBeNull();
  });

  it("renders polyline with all coordinates for a 3-point path", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045, timestamp: 1 },
      { lat: 47.6289, lon: -122.3432, timestamp: 2 },
      { lat: 47.6762, lon: -122.3187, timestamp: 3 },
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);

    const polyline = result.getByTestId("map-path-polyline");
    expect(polyline.props.coordinates).toHaveLength(3);
    expect(polyline.props.coordinates[0]).toEqual({
      latitude: 47.6419,
      longitude: -122.3045,
    });

    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
  });

  it("filters non-finite path points out of the polyline", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045 },
      { lat: NaN, lon: -122.32 },
      { lat: 47.6289, lon: -122.3432 },
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    const polyline = result.getByTestId("map-path-polyline");
    expect(polyline.props.coordinates).toHaveLength(2);
  });

  it("renders empty state when there are no pins and no path", () => {
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={[]} />,
    );
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(
      result.getByText(
        /No location yet — grab context or add a known place\./,
      ),
    ).toBeTruthy();
  });
});
