// lib/core/location_provider.dart
// Provider GPS centralisé pour toute l'application
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';

/// État de localisation avec métadonnées
class LocationState {
  final Position? position;
  final DateTime? lastUpdate;
  final bool hasPermission;
  final bool serviceEnabled;

  const LocationState({
    this.position,
    this.lastUpdate,
    this.hasPermission = false,
    this.serviceEnabled = true,
  });

  /// Conversion en LatLng pour flutter_map
  LatLng? get latLng => position != null
      ? LatLng(position!.latitude, position!.longitude)
      : null;

  /// Coordonnées simples
  double? get lat => position?.latitude;
  double? get lng => position?.longitude;

  /// Position valide ?
  bool get hasPosition => position != null;

  /// Fallback Alger centre
  static const fallbackLatLng = LatLng(36.75, 3.06);
  static const fallbackLat = 36.75;
  static const fallbackLng = 3.06;

  /// LatLng avec fallback
  LatLng get latLngOrFallback => latLng ?? fallbackLatLng;

  LocationState copyWith({
    Position? position,
    DateTime? lastUpdate,
    bool? hasPermission,
    bool? serviceEnabled,
  }) {
    return LocationState(
      position: position ?? this.position,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      hasPermission: hasPermission ?? this.hasPermission,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    );
  }
}

/// Provider central GPS - Stream continu avec updates automatiques
/// Utilisé par: Home, Map, Lists (Vet, Daycare, Petshop)
final locationStreamProvider = StreamProvider<LocationState>((ref) async* {
  // 1. Vérifier si le service de localisation est activé
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    yield const LocationState(serviceEnabled: false, hasPermission: false);
    return;
  }

  // 2. Vérifier/demander la permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield const LocationState(serviceEnabled: true, hasPermission: false);
    return;
  }

  // 3. Permission OK - récupérer position initiale rapidement
  try {
    final lastKnown = await Geolocator.getLastKnownPosition()
        .timeout(const Duration(milliseconds: 500), onTimeout: () => null);

    if (lastKnown != null) {
      yield LocationState(
        position: lastKnown,
        lastUpdate: DateTime.now(),
        hasPermission: true,
        serviceEnabled: true,
      );
    }
  } catch (_) {
    // Ignore, on va chercher la position courante
  }

  // 4. Position courante
  try {
    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    ).timeout(const Duration(seconds: 3));

    yield LocationState(
      position: current,
      lastUpdate: DateTime.now(),
      hasPermission: true,
      serviceEnabled: true,
    );
  } catch (_) {
    // Continue avec le stream même si getCurrentPosition échoue
  }

  // 5. Stream continu - update si déplacement > 25m
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25, // Mise à jour tous les 25 mètres
    ),
  ).map((pos) => LocationState(
    position: pos,
    lastUpdate: DateTime.now(),
    hasPermission: true,
    serviceEnabled: true,
  ));
});

/// Provider simple pour obtenir LatLng actuel (pour map center, etc.)
final currentLatLngProvider = Provider<LatLng>((ref) {
  final state = ref.watch(locationStreamProvider);
  return state.maybeWhen(
    data: (s) => s.latLngOrFallback,
    orElse: () => LocationState.fallbackLatLng,
  );
});

/// Provider pour coordonnées simples (lat, lng)
final currentCoordsProvider = Provider<({double lat, double lng})>((ref) {
  final state = ref.watch(locationStreamProvider);
  return state.maybeWhen(
    data: (s) => (lat: s.lat ?? LocationState.fallbackLat, lng: s.lng ?? LocationState.fallbackLng),
    orElse: () => (lat: LocationState.fallbackLat, lng: LocationState.fallbackLng),
  );
});

/// Provider pour vérifier si on a la permission GPS
final hasLocationPermissionProvider = Provider<bool>((ref) {
  final state = ref.watch(locationStreamProvider);
  return state.maybeWhen(
    data: (s) => s.hasPermission,
    orElse: () => false,
  );
});

// ─────────────────────────────────────────────────────────────────
// BACKEND SYNC - Envoi de la position au backend (throttled)
// ─────────────────────────────────────────────────────────────────

/// Timestamp du dernier envoi au backend (throttling)
DateTime? _lastBackendSync;

/// Durée minimum entre 2 envois au backend
const _syncThrottleDuration = Duration(minutes: 5);

/// Sync la position avec le backend pour les bookings actifs
/// Appelé automatiquement quand la position change
Future<void> syncLocationToBackend({
  required ApiClient api,
  required double lat,
  required double lng,
  String? daycareBookingId,
  String? vetBookingId,
}) async {
  // Throttle: max 1 appel / 5 minutes
  if (_lastBackendSync != null &&
      DateTime.now().difference(_lastBackendSync!) < _syncThrottleDuration) {
    return;
  }

  try {
    // Sync daycare booking si actif
    if (daycareBookingId != null && daycareBookingId.isNotEmpty) {
      await api.notifyDaycareClientNearby(
        daycareBookingId,
        lat: lat,
        lng: lng,
      );
    }

    // Sync vet booking si actif
    if (vetBookingId != null && vetBookingId.isNotEmpty) {
      await api.checkBookingProximity(
        bookingId: vetBookingId,
        lat: lat,
        lng: lng,
      );
    }

    _lastBackendSync = DateTime.now();
  } catch (_) {
    // Silently fail - pas critique
  }
}

/// Provider qui écoute les changements de position et sync avec le backend
/// À utiliser dans le widget principal (HomeScreen)
final locationBackendSyncProvider = Provider<void>((ref) {
  // Ce provider est "activé" quand on le watch
  // Il écoute les changements de position via locationStreamProvider
  // La logique de sync est dans le widget qui l'utilise
  return;
});
