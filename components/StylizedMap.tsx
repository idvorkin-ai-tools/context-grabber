import React, { useMemo } from "react";
import { StyleSheet, Text, View } from "react-native";
import MapView, {
  Marker,
  Polyline,
  PROVIDER_DEFAULT,
  type Region,
} from "react-native-maps";
import type { KnownPlace } from "../lib/places";
import type { LocationData } from "../lib/appTypes";
import {
  CURRENT_LOCATION_COLOR,
  PLACE_COLORS,
  UNKNOWN_PLACE_COLOR,
} from "../lib/places_colors";
import { iconForPlace } from "../lib/place_icons";

export type PathPoint = {
  lat: number;
  lon: number;
  timestamp?: number;
};

type Props = {
  currentLocation: LocationData;
  knownPlaces: KnownPlace[];
  height?: number;
  path?: PathPoint[];
  /**
   * Color per known place, keyed by `KnownPlace.name`. When provided, each
   * pin uses the matching color so the map shares its palette with the
   * Places-daily-breakdown bars (same place = same color across surfaces).
   * Missing entries fall back to PLACE_COLORS by index.
   */
  placeColors?: Map<string, string>;
};

const FALLBACK_REGION: Region = {
  latitude: 37.7749,
  longitude: -122.4194,
  latitudeDelta: 0.4,
  longitudeDelta: 0.4,
};

function computeRegion(
  currentLocation: LocationData,
  knownPlaces: KnownPlace[],
  path: PathPoint[],
): Region | null {
  const lats: number[] = [];
  const lngs: number[] = [];
  for (const p of knownPlaces) {
    lats.push(p.latitude);
    lngs.push(p.longitude);
  }
  if (currentLocation) {
    lats.push(currentLocation.latitude);
    lngs.push(currentLocation.longitude);
  }
  for (const p of path) {
    if (Number.isFinite(p.lat) && Number.isFinite(p.lon)) {
      lats.push(p.lat);
      lngs.push(p.lon);
    }
  }
  if (lats.length === 0) return null;

  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);

  const latSpan = Math.max(maxLat - minLat, 0.005);
  const lngSpan = Math.max(maxLng - minLng, 0.005);

  return {
    latitude: (minLat + maxLat) / 2,
    longitude: (minLng + maxLng) / 2,
    latitudeDelta: latSpan * 1.4,
    longitudeDelta: lngSpan * 1.4,
  };
}

function PlacePin({ color, label }: { color: string; label: string }) {
  const icon = iconForPlace(label);
  return (
    <View style={pinStyles.wrap} pointerEvents="none">
      <View style={[pinStyles.dot, { backgroundColor: color }]} />
      <View style={pinStyles.labelChip}>
        {icon && <Text style={pinStyles.iconText}>{icon} </Text>}
        <Text style={pinStyles.labelText} numberOfLines={1}>
          {label}
        </Text>
      </View>
    </View>
  );
}

function CurrentPin() {
  return (
    <View style={pinStyles.wrap} pointerEvents="none">
      <View style={pinStyles.halo} />
      <View
        style={[
          pinStyles.diamond,
          { backgroundColor: CURRENT_LOCATION_COLOR },
        ]}
      />
      <View style={[pinStyles.labelChip, pinStyles.currentLabelChip]}>
        <Text style={pinStyles.labelText}>You</Text>
      </View>
    </View>
  );
}

export function StylizedMap({
  currentLocation,
  knownPlaces,
  height = 180,
  path,
  placeColors,
}: Props) {
  const cleanPath = useMemo(
    () =>
      (path ?? []).filter(
        (p) => Number.isFinite(p.lat) && Number.isFinite(p.lon),
      ),
    [path],
  );

  const region = useMemo(
    () => computeRegion(currentLocation, knownPlaces, cleanPath),
    [currentLocation, knownPlaces, cleanPath],
  );

  if (!region) {
    return (
      <View style={[styles.frame, styles.emptyFrame, { height }]} testID="stylized-map">
        <Text style={styles.emptyText}>
          No location yet — grab context or add a known place.
        </Text>
      </View>
    );
  }

  const polylineCoords = cleanPath.map((p) => ({
    latitude: p.lat,
    longitude: p.lon,
  }));

  return (
    <View style={[styles.frame, { height }]} testID="stylized-map">
      <MapView
        provider={PROVIDER_DEFAULT}
        style={StyleSheet.absoluteFill}
        initialRegion={region ?? FALLBACK_REGION}
        showsCompass={false}
        showsScale={false}
        toolbarEnabled={false}
        rotateEnabled={false}
        pitchEnabled={false}
      >
        {knownPlaces.map((p, idx) => {
          const color =
            placeColors?.get(p.name) ?? PLACE_COLORS[idx % PLACE_COLORS.length];
          return (
            <Marker
              key={`p-${p.id}`}
              identifier={`map-pin-p-${p.id}`}
              testID={`map-pin-p-${p.id}`}
              coordinate={{ latitude: p.latitude, longitude: p.longitude }}
              title={p.name}
              anchor={{ x: 0.5, y: 0.5 }}
              tracksViewChanges={false}
            >
              <PlacePin color={color} label={p.name} />
            </Marker>
          );
        })}
        {currentLocation && (
          <Marker
            identifier="map-pin-current"
            testID="map-pin-current"
            coordinate={{
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
            }}
            title="You"
            anchor={{ x: 0.5, y: 0.5 }}
            tracksViewChanges={false}
          >
            <CurrentPin />
          </Marker>
        )}
        {polylineCoords.length >= 2 && (
          <Polyline
            testID="map-path-polyline"
            coordinates={polylineCoords}
            strokeColor="rgba(76, 201, 240, 0.85)"
            strokeWidth={3}
          />
        )}
      </MapView>
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    position: "relative",
    borderRadius: 14,
    overflow: "hidden",
    backgroundColor: "#0e1a2b",
    borderWidth: 1,
    borderColor: "#1a2a3a",
  },
  emptyFrame: {
    justifyContent: "center",
    alignItems: "center",
    padding: 16,
  },
  emptyText: { color: "#666", fontSize: 12, textAlign: "center" },
});

const pinStyles = StyleSheet.create({
  wrap: { alignItems: "center" },
  dot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: "#fff",
  },
  diamond: {
    width: 14,
    height: 14,
    borderWidth: 2,
    borderColor: "#fff",
    transform: [{ rotate: "45deg" }],
  },
  halo: {
    position: "absolute",
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(76, 201, 240, 0.22)",
    top: -9,
  },
  labelChip: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    backgroundColor: "rgba(20, 20, 30, 0.85)",
    maxWidth: 140,
  },
  currentLabelChip: {
    marginTop: 7,
    backgroundColor: "rgba(76, 201, 240, 0.9)",
  },
  labelText: {
    color: "#fff",
    fontSize: 11,
    fontWeight: "600",
  },
  iconText: {
    fontSize: 11,
  },
});
