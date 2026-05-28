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

export function StylizedMap({
  currentLocation,
  knownPlaces,
  height = 180,
  path,
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
        {knownPlaces.map((p) => (
          <Marker
            key={`p-${p.id}`}
            identifier={`map-pin-p-${p.id}`}
            testID={`map-pin-p-${p.id}`}
            coordinate={{ latitude: p.latitude, longitude: p.longitude }}
            title={p.name}
            pinColor="orange"
          />
        ))}
        {currentLocation && (
          <Marker
            identifier="map-pin-current"
            testID="map-pin-current"
            coordinate={{
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
            }}
            title="You"
            pinColor="#4cc9f0"
          />
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
