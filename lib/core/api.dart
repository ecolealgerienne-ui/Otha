// lib/core/api.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kDefaultApiBase =
    String.fromEnvironment('API_BASE', defaultValue: 'https://api.piecespro.com/api/v1');

/// Provider global pour l'ApiClient
final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(baseUrl: kDefaultApiBase);
  ref.onDispose(() => api.dispose());
  return api;
});

class ApiClient {
  final String baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        ));

  void dispose() {
    _dio.close(force: true);
  }

  // ---------------- Helpers ----------------

  // Storage keys
  static const _kTokenPrimary = 'token';
  static const _kTokenLegacy = 'auth_token';
  static const _kRefreshPrimary = 'refresh_token';
  static const _kRefreshLegacy  = 'refreshToken';

  Future<void> setToken(String? token) async {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      await _storage.delete(key: _kTokenPrimary);
      await _storage.delete(key: _kTokenLegacy);
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      await _storage.write(key: _kTokenPrimary, value: token);
      await _storage.write(key: _kTokenLegacy, value: token);
    }
  }

  Future<void> setRefreshToken(String? rt) async {
    if (rt == null || rt.isEmpty) {
      await _storage.delete(key: _kRefreshPrimary);
      await _storage.delete(key: _kRefreshLegacy);
    } else {
      await _storage.write(key: _kRefreshPrimary, value: rt);
      await _storage.write(key: _kRefreshLegacy, value: rt);
    }
  }

  Future<String?> getStoredRefreshToken() async {
    final r1 = await _storage.read(key: _kRefreshPrimary);
    if (r1 != null && r1.isNotEmpty) return r1;
    final r2 = await _storage.read(key: _kRefreshLegacy);
    return (r2 != null && r2.isNotEmpty) ? r2 : null;
  }

  Future<String?> getStoredToken() async {
    final t1 = await _storage.read(key: _kTokenPrimary);
    if (t1 != null && t1.isNotEmpty) return t1;
    final t2 = await _storage.read(key: _kTokenLegacy);
    return (t2 != null && t2.isNotEmpty) ? t2 : null;
  }

  Future<void> ensureAuth({bool forceReload = false}) async {
    final hasHeader = _dio.options.headers['Authorization'] is String;
    if (!hasHeader || forceReload) {
      final t = await getStoredToken();
      if (t != null && t.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $t';
      } else {
        _dio.options.headers.remove('Authorization');
      }
    }
  }

  Future<bool> _tryRefresh() async {
    final rt = await getStoredRefreshToken();
    if (rt == null || rt.isEmpty) return false;

    try {
      final dio2 = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final res = await dio2.post('/auth/refresh', data: {'refreshToken': rt});
      final data = _unwrap<Map<String, dynamic>>(res.data);

      final newAccess  = (data['accessToken'] ?? data['token'] ?? '') as String;
      final newRefresh = (data['refreshToken'] ?? data['refresh_token'] ?? '') as String?;
      if (newAccess.isEmpty) return false;

      await setToken(newAccess);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await setRefreshToken(newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
  

  Future<T> _authRetry<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return await run();
        }
      }
      rethrow;
    }
  }

  T _unwrap<T>(dynamic resp, {T Function(dynamic data)? map}) {
    if (resp is Map && resp['data'] != null) {
      final d = resp['data'];
      return map != null ? map(d) : d as T;
    }
    return map != null ? map(resp) : resp as T;
  }

  String _isoDateOrUtcMidnight(String value) {
    final s = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      return DateTime.parse('${s}T00:00:00.000Z').toIso8601String();
    }
    try {
      return DateTime.parse(s).toUtc().toIso8601String();
    } catch (_) {
      return s;
    }
  }

  String _extractMessage(dynamic data) {
    if (data == null) return 'Requête invalide (400)';
    if (data is String) return data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is List) return msg.join('\n');
      if (msg is String) return msg;
    }
    return data.toString();
  }

  // ---------------- Auth ----------------

  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        if (fullName != null && fullName.trim().isNotEmpty)
          'firstName': fullName.trim(),
      });
      _unwrap(res.data);
      return true;
    } on DioException catch (e) {
      debugPrint('register error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  Future<String> login({required String email, required String password}) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = _unwrap<Map<String, dynamic>>(res.data);

    final access  = (data['accessToken'] ?? data['token'] ?? '') as String;
    if (access.isEmpty) throw Exception('Token manquant');

    final refresh = (data['refreshToken'] ?? data['refresh_token'] ?? '') as String?;
    await setToken(access);
    await setRefreshToken(refresh);
    return access;
  }

  Future<void> logout() async {
    _dio.options.headers.remove('Authorization');
    await _storage.delete(key: _kTokenPrimary);
    await _storage.delete(key: _kTokenLegacy);
    await setRefreshToken(null);
    await _storage.delete(key: 'my_provider_id');
  }

  Future<Map<String, dynamic>> me() async {
    await ensureAuth();
    final res = await _dio.get('/users/me');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  // ====== user profile ======
  Future<Map<String, dynamic>> updateMe({
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    double? lat,
    double? lng,
    String? photoUrl,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    final res = await _dio.patch('/users/me', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> meUpdate({
    String? phone,
    String? city,
    double? lat,
    double? lng,
    String? photoUrl,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    if (body.isEmpty) return me();

    try {
      final res = await _authRetry(() async => await _dio.patch('/users/me', data: body));
      return _unwrap<Map<String, dynamic>>(res.data);
    } on DioException catch (e) {
      final msg = (e.response?.data ?? '').toString();
      final code = e.response?.statusCode ?? 0;

      final looksLikePhotoRejected = (code == 400 || code == 500) &&
          (msg.contains('photoUrl') || msg.contains('Unknown argument') || msg.contains('non-whitelisted'));
      if (looksLikePhotoRejected && body.containsKey('photoUrl')) {
        body.remove('photoUrl');
        final res2 = await _authRetry(() async => await _dio.patch('/users/me', data: body));
        return _unwrap<Map<String, dynamic>>(res2.data);
      }

      if (code == 404) throw Exception('Endpoint /users/me indisponible (404)');
      throw Exception(_extractMessage(e.response?.data));
    }
  }

  // ====== upload (avatar / photos) ======
  Future<String> uploadLocalFile(File file) async {
    await ensureAuth();

    final filename = file.path.split(Platform.pathSeparator).last;

    final candidates = <String>['/uploads/local', '/upload/local', '/uploads', '/upload'];

    DioException? last;
    for (final path in candidates) {
      try {
        final res = await _authRetry(() async {
          final form = FormData.fromMap({
            'file': await MultipartFile.fromFile(file.path, filename: filename),
          });
          return await _dio.post(path, data: form);
        });
        final m = _unwrap<Map<String, dynamic>>(res.data);
        final url = (m['url'] ??
                m['Location'] ??
                m['location'] ??
                m['publicUrl'] ??
                m['public_url'] ??
                '')
            .toString();
        if (url.isNotEmpty) return url;

        final loc = res.headers['location']?.first;
        if (loc != null && loc.isNotEmpty) return loc;
      } on DioException catch (e) {
        last = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    try {
      final ext = _extensionOf(filename);
      final mime = _mimeFromExtension(ext);
      final presign = await _authRetry(
        () async => await _dio.post('/uploads/presign', data: {
          'mimeType': mime,
          'folder': 'uploads',
          'ext': ext,
        }),
      );
      final m = _unwrap<Map<String, dynamic>>(presign.data);
      final putUrl = (m['url'] ?? '') as String;
      if (putUrl.isEmpty) throw Exception('Presign: url manquante');

      final bytes = await file.readAsBytes();
      await Dio().put(
        putUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': mime}),
      );

      final publicUrl = (m['publicUrl'] ?? m['public_url'] ?? '') as String;
      if (publicUrl.isNotEmpty) return publicUrl;

      final bucket = (m['bucket'] ?? '') as String;
      final key = (m['key'] ?? '') as String;
      final publicBase = const String.fromEnvironment('S3_PUBLIC_ENDPOINT', defaultValue: '');
      if (publicBase.isNotEmpty && bucket.isNotEmpty && key.isNotEmpty) {
        return '${publicBase.replaceAll(RegExp(r'/+$'), '')}/$bucket/$key';
      }

      throw Exception('Impossible de déduire l’URL publique');
    } catch (e) {
      throw last ??
          (e is DioException
              ? e
              : DioException(requestOptions: RequestOptions(path: '/uploads/local'), error: e));
    }
  }

  String _extensionOf(String filename) {
    final i = filename.lastIndexOf('.');
    if (i >= 0 && i < filename.length - 1) {
      return filename.substring(i + 1).toLowerCase();
    }
    return '';
  }

  String _mimeFromExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'gif') return 'image/gif';
    if (e == 'webp') return 'image/webp';
    if (e == 'mp4') return 'video/mp4';
    return 'application/octet-stream';
  }

  // --------------- Availability (SANS FUSEAU) ---------------

  Future<Map<String, dynamic>> myWeekly() async {
    await ensureAuth();
    final res = await _dio.get('/providers/me/availability');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> setWeekly(List<Map<String, dynamic>> entries) async {
    await ensureAuth();
    await _dio.post('/providers/me/availability', data: {'entries': entries});
  }

  Future<void> addTimeOff({
    required String startsAtIso,
    required String endsAtIso,
    String? reason,
  }) async {
    await ensureAuth();

    final bodyPlural = <String, dynamic>{
      'startsAt': startsAtIso,
      'endsAt'  : endsAtIso,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    try {
      await _dio.post('/providers/me/time-offs', data: bodyPlural);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }

    final bodySingular = <String, dynamic>{
      'start': startsAtIso,
      'end'  : endsAtIso,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    await _dio.post('/providers/me/time-off', data: bodySingular);
  }

  Future<List<Map<String, dynamic>>> myTimeOffs() async {
    await ensureAuth();
    final res = await _dio.get('/providers/me/time-offs');
    final list = _unwrap<List<dynamic>>(res.data, map: (d) => d as List);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> deleteMyTimeOff(String id) async {
    await ensureAuth();
    await _dio.delete('/providers/me/time-offs/$id');
  }

  /// Slots naïfs groupés par jour (labels formattés par le back)
  Future<Map<String, dynamic>> providerSlotsNaive({
    required String providerId,
    required int durationMin,
    int days = 14,
    int stepMin = 30,
    DateTime? from,
  }) async {
    final start = (from ?? DateTime.now().toUtc());
    final end   = start.add(Duration(days: days));

    final res = await _dio.get(
      '/providers/$providerId/slots-naive',
      queryParameters: {
        'from': start.toIso8601String(),
        'to'  : end.toIso8601String(),
        'step': '$stepMin',
        'duration': '$durationMin',
      },
    );

    final d = res.data;
    if (d is Map && d['data'] is Map) {
      return Map<String, dynamic>.from(d['data']);
    }
    return (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  // ========= Providers (public) =========

  String sanitizeGoogleMapsUrl(String? u) {
  if (u == null || u.trim().isEmpty) return '';
  Uri uri;
  try {
    uri = Uri.parse(u.trim());
  } catch (_) {
    return u;
  }

  // normalise host → www.google.com si c’est déjà Google
  final host = uri.host.contains('google.') ? 'www.google.com' : uri.host;

  // filtre paramètres parasites
  final banned = {
    'ts','entry','g_ep','utm_source','utm_medium','utm_campaign','utm_term',
    'utm_content','hl','ved','source','opi','sca_esv'
  };
  final qp = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((k, _) => banned.contains(k));

  final clean = uri.replace(host: host, queryParameters: qp);

  // évite doubles // et conserve path
  final path = clean.path.replaceAll(RegExp(r'/+'), '/');
  return clean.replace(path: path).toString();
}


  /// Backend-first: on envoie displayName/adresse/specialties (mapsUrl inclus).
  /// Le back gère l’expansion des liens Google Maps et l’extraction lat/lng.
  Future<Map<String, dynamic>> upsertMyProvider({
    required String displayName,
    String? bio,
    String? address,
    double? lat,
    double? lng,
    Map<String, dynamic>? specialties,
    bool forceReparse = false,
    String? timezone,
  }) async {
    await ensureAuth();

    bool _validCoord(double? v) => v != null && v.isFinite && v != 0.0;

    final body = <String, dynamic>{
      'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (address != null) 'address': address,
      if (timezone != null) 'timezone': timezone,
      if (specialties != null) 'specialties': specialties,
      'forceReparse': forceReparse,
      // si le front n’envoie pas lat/lng, le back recalcule depuis mapsUrl
      if (!forceReparse && _validCoord(lat)) 'lat': lat,
      if (!forceReparse && _validCoord(lng)) 'lng': lng,
    };

    final res = await _dio.post(
      '/providers/me',
      data: _dropNulls(body),
      options: Options(contentType: 'application/json'),
    );

    final m = _unwrap<Map<String, dynamic>>(res.data);
    final pid = (m['id'] ?? '').toString();
    if (pid.isNotEmpty) await _cacheMyProviderId(pid);
    return m;
  }

  /// Met à jour uniquement la visibilité en MERGEant specialties existant (garde kind/mapsUrl).
  Future<void> setMyVisibility(bool visible) async {
    await ensureAuth();

    final meProv = await myProvider(); // peut être null
    final currentSpec = Map<String, dynamic>.from(
      (meProv?['specialties'] as Map?) ?? const {},
    );
    currentSpec['visible'] = visible;

    final payload = _dropNulls({'specialties': currentSpec});

    try {
      await _dio.post('/providers/me', data: payload);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }

    try {
      await _dio.patch('/providers/me', data: payload);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }

    final pid = (meProv?['id'] ?? '').toString();
    if (pid.isEmpty) {
      throw Exception("Impossible de modifier la visibilité (providerId introuvable).");
    }
    await _dio.patch('/providers/$pid', data: payload);
  }

  Map<String, dynamic> _dropNulls(Map<String, dynamic> src) {
    final out = <String, dynamic>{};
    src.forEach((k, v) {
      if (v == null) return;
      if (v is Map<String, dynamic>) {
        final nested = _dropNulls(v);
        if (nested.isNotEmpty) out[k] = nested;
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  Future<void> _cacheMyProviderId(String id) async {
    if (id.isEmpty) return;
    await _storage.write(key: 'my_provider_id', value: id);
  }

  Future<String?> _getCachedMyProviderId() => _storage.read(key: 'my_provider_id');

  Future<Map<String, dynamic>?> myProvider() async {
    await ensureAuth();
    try {
      final res = await _dio.get('/providers/me');
      final m = _unwrap<Map<String, dynamic>>(res.data);
      final pid = (m['id'] ?? '').toString();
      if (pid.isNotEmpty) await _cacheMyProviderId(pid);
      return m;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> providerDetails(String providerId) async {
    final res = await _dio.get('/providers/$providerId');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Recherche proximité (si radiusKm=0 -> pas de filtre côté back).
  Future<List<dynamic>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 30000,
    int limit = 200,
    int offset = 0,
    String status = 'approved',
  }) async {
    final res = await _dio.get('/providers/nearby', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      'limit': limit,
      'offset': offset,
      'status': status,
    });
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<List<dynamic>> listAllProviders({
    int limit = 500,
    int offset = 0,
    String status = 'approved',
  }) {
    return nearby(
      lat: 0.0,
      lng: 0.0,
      radiusKm: 0.0, // aucun filtre de rayon côté back
      limit: limit,
      offset: offset,
      status: status,
    );
  }

  /// Variante tolérante : si lat/lng invalides -> radius=0 (fetch global).
  Future<List<dynamic>> safeNearby({
    double? lat,
    double? lng,
    double radiusKm = 3000,
    int limit = 200,
    int offset = 0,
    String status = 'approved',
  }) {
    final okLat = (lat ?? 0.0);
    final okLng = (lng ?? 0.0);
    final invalid = !okLat.isFinite || !okLng.isFinite;
    final useRadius = invalid ? 0.0 : radiusKm;
    return nearby(
      lat: invalid ? 0.0 : okLat,
      lng: invalid ? 0.0 : okLng,
      radiusKm: useRadius,
      limit: limit,
      offset: offset,
      status: status,
    );
  }

  // ========= Services (public / connecté) =========

  Future<List<dynamic>> myServices() async {
    await ensureAuth();

    final cachedId = await _getCachedMyProviderId();

    try {
      final res = await _dio.get('/providers/me/services');
      final viaMe = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
      if (viaMe.isEmpty && cachedId != null && cachedId.isNotEmpty) {
        final res2 = await _dio.get('/providers/$cachedId/services');
        final viaPublic = _unwrap<List<dynamic>>(res2.data, map: (d) => (d as List).cast<dynamic>());
        if (viaPublic.isNotEmpty) return viaPublic;
      }
      return viaMe;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 ||
          e.response?.statusCode == 403 ||
          e.response?.statusCode == 404) {
        if (cachedId != null && cachedId.isNotEmpty) {
          final res2 = await _dio.get('/providers/$cachedId/services');
          return _unwrap<List<dynamic>>(res2.data, map: (d) => (d as List).cast<dynamic>());
        }
        final me = await myProvider();
        final pid = (me?['id'] ?? '').toString();
        if (pid.isNotEmpty) {
          final res3 = await _dio.get('/providers/$pid/services');
          return _unwrap<List<dynamic>>(res3.data, map: (d) => (d as List).cast<dynamic>());
        }
        return <dynamic>[];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createMyService({
    required String title,
    required int durationMin, // >= 15
    int? price,
    bool? atHome, // ignoré
    String? description,
  }) async {
    await ensureAuth();
    if (title.trim().isEmpty) throw Exception('Le titre est requis.');
    if (durationMin < 15) throw Exception('La durée doit être au moins 15 minutes.');

    final body = <String, dynamic>{
      'title': title.trim(),
      'durationMin': durationMin,
      if (price != null) 'price': price,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };

    try {
      final res = await _dio.post('/providers/me/services', data: body);
      final m = _unwrap<Map<String, dynamic>>(res.data);
      final pid = (m['providerId'] ?? '').toString();
      if (pid.isNotEmpty) await _cacheMyProviderId(pid);
      return m;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e.response?.data));
    }
  }

  Future<Map<String, dynamic>> updateMyService(
    String serviceId, {
    String? title,
    int? durationMin,
    int? price,
    bool? atHome, // ignoré
    String? description,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (durationMin != null) 'durationMin': durationMin,
      if (price != null) 'price': price,
      if (description != null) 'description': description.trim(),
    };

    try {
      final res = await _dio.patch('/providers/me/services/$serviceId', data: body);
      return _unwrap<Map<String, dynamic>>(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          final res2 = await _dio.patch('/services/$serviceId', data: body);
          return _unwrap<Map<String, dynamic>>(res2.data);
        } on DioException catch (e2) {
          throw Exception('Aucune route d’update trouvée (404)\n${e2.response?.data}');
        }
      }
      throw Exception(_extractMessage(e.response?.data));
    }
  }

  Future<void> deleteMyService(String serviceId) async {
    await ensureAuth();
    try {
      await _dio.delete('/providers/me/services/$serviceId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          await _dio.delete('/services/$serviceId');
        } on DioException catch (e2) {
          throw Exception('Aucune route de suppression trouvée (404)\n${e2.response?.data}');
        }
        return;
      }
      throw Exception(_extractMessage(e.response?.data));
    }
  }

  // --------------- Bookings ---------------

  Future<Map<String, dynamic>> createBooking({
    required String serviceId,
    required String scheduledAtIso,
  }) async {
    await ensureAuth();
    final res =
        await _dio.post('/bookings', data: {'serviceId': serviceId, 'scheduledAt': scheduledAtIso});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<List<dynamic>> myBookings() async {
    await ensureAuth();
    final res = await _dio.get('/bookings/mine');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

Future<List<Map<String, dynamic>>> providerAgenda({
  String? fromIso,
  String? toIso,
  String? status,     // optionnel, utile pour filtrer côté back si dispo
  String? providerId, // optionnel
}) async {
  await ensureAuth();
  final qp = <String, dynamic>{
    if (fromIso != null) 'from': fromIso,
    if (toIso != null) 'to': toIso,
    if (status != null) 'status': status,
    if (providerId != null) 'providerId': providerId,
  };

  final paths = <String>[
    '/bookings/provider/me',        // actuel
    '/bookings/provider/agenda',
    '/providers/me/agenda',
    '/bookings/agenda/me',
    '/bookings/agenda',
  ];

  DioException? last;
  for (final p in paths) {
    try {
      final r = await _authRetry(() async => await _dio.get(p, queryParameters: qp));
      final data = (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      final list = (data is List) ? data : (data is Map && data['items'] is List ? data['items'] : null);
      if (list == null) continue;

      // Normalisation forte: scheduledAt + status UPPERCASE
      return list.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        if (!m.containsKey('scheduledAt') && m['scheduled_at'] != null) {
          m['scheduledAt'] = m['scheduled_at'];
        }
        m['status'] = (m['status'] ?? '').toString().toUpperCase();
        return m;
      }).toList();
    } on DioException catch (e) {
      last = e;
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 405 || code == 403) continue;
      rethrow;
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}


  Future<Map<String, dynamic>> providerSetStatus({
    required String bookingId,
    required String status,
  }) async {
    await ensureAuth();
    final res =
        await _dio.patch('/bookings/$bookingId/provider-status', data: {'status': status});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> setMyBookingStatus({
    required String bookingId,
    required String status, // 'CANCELLED' etc.
  }) async {
    await ensureAuth();
    final res = await _dio.patch('/bookings/$bookingId/status', data: {'status': status});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> cancelMyBooking(String bookingId) async {
    await ensureAuth();

    try {
      final res = await _dio.post('/bookings/$bookingId/cancel');
      return _unwrap<Map<String, dynamic>>(res.data);
    } catch (e) {}

    try {
      final res = await _dio.patch('/bookings/$bookingId/user-status', data: {'status': 'CANCELLED'});
      return _unwrap<Map<String, dynamic>>(res.data);
    } catch (e) {}

    final res = await _dio.patch('/bookings/$bookingId/status', data: {'status': 'CANCELLED'});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> rescheduleMyBooking({
    required String bookingId,
    required String scheduledAtIso,
  }) async {
    await ensureAuth();

    try {
      final res = await _dio.patch('/bookings/$bookingId/reschedule', data: {'scheduledAt': scheduledAtIso});
      return _unwrap<Map<String, dynamic>>(res.data);
    } catch (e) {}

    try {
      final res = await _dio.post('/bookings/$bookingId/reschedule', data: {'scheduledAt': scheduledAtIso});
      return _unwrap<Map<String, dynamic>>(res.data);
    } catch (e) {}

    final res = await _dio.patch('/bookings/$bookingId', data: {'scheduledAt': scheduledAtIso});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  // --------------- Reviews ---------------
  Future<Map<String, dynamic>> createReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await ensureAuth();
    final res = await _dio.post('/reviews',
        data: {'bookingId': bookingId, 'rating': rating, if (comment != null) 'comment': comment});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  // --------------- Pets ---------------
  Future<Map<String, dynamic>> createPet({
    required String name,
    required String gender,
    double? weightKg,
    String? color,
    String? country,
    String? idNumber,
    String? breed,
    String? neuteredAtIso,
    String? photoUrl,
  }) async {
    await ensureAuth();

    Map<String, dynamic> _buildBody({bool withPhoto = true}) => <String, dynamic>{
          'name': name,
          'gender': gender,
          if (weightKg != null) 'weightKg': weightKg,
          if (color != null) 'color': color,
          if (country != null) 'country': country,
          if (idNumber != null) 'idNumber': idNumber,
          if (breed != null) 'breed': breed,
          if (neuteredAtIso != null) 'neuteredAt': _isoDateOrUtcMidnight(neuteredAtIso),
          if (withPhoto && photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        };

    try {
      final res = await _authRetry(() async => await _dio.post('/pets', data: _buildBody(withPhoto: true)));
      return _unwrap<Map<String, dynamic>>(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.response?.data?.toString() ?? '';
      final looksLikePhotoUrlRejected = status == 400 &&
          (msg.contains('photoUrl') ||
              msg.contains('should not exist') ||
              msg.contains('Unknown arg') ||
              msg.contains('non-whitelisted'));

      if (looksLikePhotoUrlRejected) {
        final res2 = await _authRetry(() async => await _dio.post('/pets', data: _buildBody(withPhoto: false)));
        return _unwrap<Map<String, dynamic>>(res2.data);
      }
      rethrow;
    }
  }

  Future<List<dynamic>> myPets() async {
    await ensureAuth();
    try {
      final res = await _dio.get('/pets/mine');
      return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res2 = await _dio.get('/pets');
        return _unwrap<List<dynamic>>(res2.data, map: (d) => (d as List).cast<dynamic>());
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePet(
    String petId, {
    String? name,
    String? breed,
    String? color,
    String? photoUrl,
    double? weightKg,
    String? gender,
    String? neuteredAtIso,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (breed != null) 'breed': breed,
      if (color != null) 'color': color,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (weightKg != null) 'weightKg': weightKg,
      if (gender != null) 'gender': gender,
      if (neuteredAtIso != null) 'neuteredAt': _isoDateOrUtcMidnight(neuteredAtIso),
    };
    final res = await _dio.patch('/pets/$petId', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<bool> deletePet(String petId) async {
    await ensureAuth();
    try {
      await _dio.delete('/pets/$petId');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }


  // --------------- Adoption (Tinder-like) ---------------

// PUBLIC feed (auth facultative)
Future<Map<String, dynamic>> adoptFeed({
  double? lat,
  double? lng,
  double? radiusKm,
  int limit = 20,
  String? cursor,
}) async {
  await ensureAuth();
  final qp = <String, dynamic>{
    'limit': limit,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (radiusKm != null) 'radiusKm': radiusKm,
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
  };

  final res = await _dio.get('/adopt/feed', queryParameters: qp);
  final raw = res.data;

  final payload = (raw is Map && raw['data'] != null) ? raw['data'] : raw;

  List items = const [];
  String? next;

  if (payload is List) {
    items = payload;
    if (raw is Map && raw['nextCursor'] != null) next = raw['nextCursor'].toString();
  } else if (payload is Map) {
    final maybeItems = payload['items'] ?? payload['data'] ?? const [];
    if (maybeItems is List) items = maybeItems;
    next = (payload['nextCursor'] ?? (raw is Map ? raw['nextCursor'] : null))?.toString();
  }

  return {
    'items': items.cast<dynamic>(),
    'nextCursor': next,
  };
}


// PUBLIC: détail d’un post approuvé
Future<Map<String, dynamic>> getAdoptPost(String id) async {
  final res = await _dio.get('/adopt/posts/$id');
  return _unwrap<Map<String, dynamic>>(res.data);
}

// AUTH: créer un post
Future<Map<String, dynamic>> createAdoptPost({
  required String petName,
  required String species,
  String sex = 'U',   // 'M' | 'F' | 'U'
  String? age,        // ex: "3 mois", "2 ans"
  required String city,
  double? lat,
  double? lng,
  String? desc,
  required List<String> photos,
}) async {
  await ensureAuth();
  final body = <String, dynamic>{
    'petName': petName,
    'species': species,
    'sex': sex,
    if (age != null && age.trim().isNotEmpty) 'age': age.trim(),
    'city': city,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (desc != null && desc.trim().isNotEmpty) 'desc': desc.trim(),
    'photos': photos,
  };
  final res = await _authRetry(() async => await _dio.post('/adopt/posts', data: body));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// AUTH: éditer un post (propriétaire)
Future<Map<String, dynamic>> updateAdoptPost(
  String postId, {
  String? petName,
  String? species,
  String? sex,   // 'M' | 'F' | 'U'
  String? age,
  String? city,
  double? lat,
  double? lng,
  String? desc,
  List<String>? photos,
}) async {
  await ensureAuth();
  final body = <String, dynamic>{
    if (petName != null) 'petName': petName,
    if (species != null) 'species': species,
    if (sex != null) 'sex': sex,
    if (age != null) 'age': age,
    if (city != null) 'city': city,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (desc != null) 'desc': desc,
    if (photos != null) 'photos': photos,
  };
  final res = await _authRetry(() async => await _dio.patch('/adopt/posts/$postId', data: body));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// AUTH: supprimer (archiver côté back) un post (propriétaire)
Future<bool> deleteAdoptPost(String postId) async {
  await ensureAuth();
  try {
    await _authRetry(() async => await _dio.delete('/adopt/posts/$postId'));
    return true;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return false;
    rethrow;
  }
}

// AUTH: mes posts
Future<List<Map<String, dynamic>>> myAdoptPosts() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/posts'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// AUTH: swiper un post (like/pass)
// remplace la version actuelle
Future<Map<String, dynamic>> adoptSwipe({
  String? postId,
  String? listingId,
  required String action, // 'like' | 'pass'
}) async {
  await ensureAuth();
  final id = (postId ?? listingId ?? '').trim();
  if (id.isEmpty) {
    throw Exception('adoptSwipe: postId/listingId manquant');
  }
  final res = await _authRetry(() async => await _dio.post(
        '/adopt/posts/$id/swipe',
        data: {'action': action},
      ));
  return _unwrap<Map<String, dynamic>>(res.data);
}


// AUTH: mes likes
Future<List<Map<String, dynamic>>> adoptMyLikes() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/likes'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// ===================== Adoption Admin (modération) =====================

// GET /admin/adopt/posts?status=...
Future<Map<String, dynamic>> adminAdoptList({
  String status = 'PENDING', // PENDING | APPROVED | REJECTED | ARCHIVED
  int limit = 20,
  String? cursor,
}) async {
  await ensureAuth();
  final qp = <String, dynamic>{
    'status': status,
    'limit': limit,
    if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
  };
  final res = await _authRetry(() async => await _dio.get('/admin/adopt/posts', queryParameters: qp));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /admin/adopt/posts/:id/approve
Future<Map<String, dynamic>> adminAdoptApprove(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/admin/adopt/posts/$postId/approve'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /admin/adopt/posts/:id/reject
Future<Map<String, dynamic>> adminAdoptReject(String postId, {String? note}) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch(
        '/admin/adopt/posts/$postId/reject',
        data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /admin/adopt/posts/:id/archive
Future<Map<String, dynamic>> adminAdoptArchive(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/admin/adopt/posts/$postId/archive'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// ---------------- Wrappers rétrocompat (si ton UI les appelle déjà) ----------------

@deprecated
Future<Map<String, dynamic>> createAdoptListing({
  required String petName,
  required String species,
  String sex = 'U',
  String? age,
  required String city,
  double? lat,
  double? lng,
  String? desc,
  required List<String> photos,
}) =>
    createAdoptPost(
      petName: petName,
      species: species,
      sex: sex,
      age: age,
      city: city,
      lat: lat,
      lng: lng,
      desc: desc,
      photos: photos,
    );

@deprecated
Future<List<Map<String, dynamic>>> myAdoptListings() => myAdoptPosts();

@deprecated
Future<Map<String, dynamic>> archiveAdoptListing(String postId) async {
  final ok = await deleteAdoptPost(postId);
  return {'ok': ok};
}



// --- PRO: historique mensuel (accès pro, sans providerId) ---
Future<List<Map<String, dynamic>>> myHistoryMonthly({int months = 24}) async {
  await ensureAuth();

  String _canonYm(String s) {
    final t = s.replaceAll('/', '-').trim();
    final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(t);
    if (m == null) return t;
    final y = m.group(1)!;
    final mo = int.parse(m.group(2)!);
    return '$y-${mo.toString().padLeft(2, '0')}';
  }

  final r = await _authRetry(() async => await _dio.get(
        '/earnings/me/history-monthly',
        queryParameters: {'months': months},
      ));

  final payload = (r.data is Map) ? (r.data['data'] ?? r.data) : r.data;
  final list = (payload is List) ? payload : const [];

  return list.map<Map<String, dynamic>>((e) {
    final m = Map<String, dynamic>.from(e as Map);
    m['month'] = _canonYm((m['month'] ?? '').toString());

    final due = _asInt(m['dueDa']);
    int coll = _asInt(m['collectedDa']);
    if (due > 0 && coll > due) coll = due;
    m['dueDa'] = due;
    m['collectedDa'] = coll;

    return m;
  }).toList();
}

// -------- PRO: earnings par mois --------
Future<Map<String, dynamic>> myEarnings({required String month}) async {
  await ensureAuth();
  final r = await _authRetry(() async => await _dio.get(
        '/earnings/me/earnings',
        queryParameters: {'month': month},
      ));
  final payload = (r.data is Map) ? (r.data['data'] ?? r.data) : r.data;
  return (payload is Map)
      ? Map<String, dynamic>.from(payload)
      : <String, dynamic>{};
}



// ============================ ADMIN (via /earnings) ============================

// --- Helpers (réutilise ton _asInt global si déjà présent) ---
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// ───────────────────────── Providers admin (inchangé) ─────────────────────────

Future<List<dynamic>> listProviderApplications({
  String status = 'pending',
  int limit = 100,
  int offset = 0,
}) async {
  await ensureAuth();
  final paths = <String>[
    '/providers/admin/applications',
    '/admin/providers/applications',
    '/providers/applications',
  ];
  DioException? last;
  for (final p in paths) {
    try {
      final r = await _authRetry(() async => await _dio.get(p, queryParameters: {
            'status': status,
            'limit': limit,
            'offset': offset,
          }));
      final data =
          (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      if (data is List) return data.cast<dynamic>();
    } on DioException catch (e) {
      last = e;
      if ((e.response?.statusCode ?? 0) == 404) continue;
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}

Future<Map<String, dynamic>> approveProvider(String providerId) async {
  await ensureAuth();
  final paths = <String>[
    '/providers/admin/applications/$providerId/approve',
    '/admin/providers/applications/$providerId/approve',
    '/providers/$providerId/approve',
  ];
  DioException? last;
  for (final p in paths) {
    try {
      final r = await _authRetry(() async => await _dio.post(p));
      final data =
          (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      return Map<String, dynamic>.from(data as Map);
    } on DioException catch (e) {
      last = e;
      if ((e.response?.statusCode ?? 0) == 404) continue;
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}

Future<Map<String, dynamic>> rejectProvider(String providerId) async {
  await ensureAuth();
  final paths = <String>[
    '/providers/admin/applications/$providerId/reject',
    '/admin/providers/applications/$providerId/reject',
    '/providers/$providerId/reject',
  ];
  DioException? last;
  for (final p in paths) {
    try {
      final r = await _authRetry(() async => await _dio.post(p));
      final data =
          (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      return Map<String, dynamic>.from(data as Map);
    } on DioException catch (e) {
      last = e;
      if ((e.response?.statusCode ?? 0) == 404) continue;
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}

Future<Map<String, dynamic>> adminUpdateProvider(
  String providerId, {
  double? lat,
  double? lng,
  String? mapsUrl,
  bool? visible,
  String? kind,
  String? displayName,
  String? address,
}) async {
  await ensureAuth();
  if (lat == null &&
      lng == null &&
      mapsUrl == null &&
      visible == null &&
      kind == null &&
      displayName == null &&
      address == null) {
    throw Exception('Aucune donnée à mettre à jour');
  }

  final sanitized = (mapsUrl == null) ? null : sanitizeGoogleMapsUrl(mapsUrl);

  Map<String, dynamic> nestedPayload() => _dropNulls({
        if (displayName != null) 'displayName': displayName,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'specialties': _dropNulls({
          if (sanitized != null) 'mapsUrl': sanitized,
          if (visible != null) 'visible': visible,
          if (kind != null) 'kind': kind,
        }),
      });

  Map<String, dynamic> flatPayload() => _dropNulls({
        if (displayName != null) 'displayName': displayName,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (sanitized != null) 'mapsUrl': sanitized,
        if (visible != null) 'visible': visible,
        if (kind != null) 'kind': kind,
      });

  final paths = <String>[
    '/providers/admin/$providerId',
    '/admin/providers/$providerId',
    '/providers/$providerId',
  ];

  DioException? lastErr;
  Future<Map<String, dynamic>> _try(
      String path, Map<String, dynamic> payload) async {
    final res =
        await _authRetry(() async => await _dio.patch(path, data: payload));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  for (final path in paths) {
    try {
      return await _try(path, nestedPayload());
    } on DioException catch (e) {
      lastErr = e;
      final code = e.response?.statusCode ?? 0;
      if (code == 404) continue;

      final msg = (e.response?.data is Map
              ? e.response?.data['message']
              : e.response?.data)
          ?.toString();
      final rejectNested = code >= 400 &&
          code < 500 &&
          msg != null &&
          (msg.contains('specialties') ||
              msg.contains('Unknown') ||
              msg.contains('non-whitelisted') ||
              msg.contains('should not exist'));
      if (rejectNested) {
        try {
          return await _try(path, flatPayload());
        } on DioException catch (e2) {
          lastErr = e2;
          if ((e2.response?.statusCode ?? 0) == 404) continue;
        }
      }
    }
  }
  throw Exception(_extractMessage(lastErr?.response?.data));
}

Future<List<dynamic>> adminListUsers({
  String? q,
  int limit = 500,
  int offset = 0,
  String? role,
}) async {
  await ensureAuth();
  // Ajout de chemins fallback fréquents
  final candidates = <String>[
    '/admin/users',
    '/users/admin',
    '/users',
    '/admin/users/list',
    '/users/list',
  ];

  DioException? last;
  for (final path in candidates) {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (role != null && role.isNotEmpty) 'role': role,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        // certains back attendent "search" plutôt que "q"
        if (q != null && q.trim().isNotEmpty) 'search': q.trim(),
      };

      final r = await _authRetry(() async => await _dio.get(
            path,
            queryParameters: params,
          ));
      final data =
          (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      if (data is List) return data.cast<dynamic>();
    } on DioException catch (e) {
      last = e;
      if ((e.response?.statusCode ?? 0) == 404) continue; // on teste le suivant
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}


// ───────────────────────── Earnings admin (NOUVEAU) ─────────────────────────

// Historique mensuel ADMIN pour un provider
Future<List<Map<String, dynamic>>> adminHistoryMonthly({
  required String providerId,
  int months = 12,
}) async {
  await ensureAuth();
  final r = await _authRetry(() async => await _dio.get(
        '/earnings/admin/history-monthly',
        queryParameters: {'providerId': providerId, 'months': months},
      ));
  final payload = (r.data is Map) ? (r.data['data'] ?? r.data) : r.data;
  final list = (payload is List) ? payload : const [];
  return list.map<Map<String, dynamic>>((e) {
    final m = Map<String, dynamic>.from(e as Map);
    final due = _asInt(m['dueDa']);
    int coll = _asInt(m['collectedDa']);
    if (due > 0 && coll > due) coll = due; // clamp sécurité
    m['dueDa'] = due;
    m['collectedDa'] = coll;
    return m;
  }).toList();
}

// Marquer un mois collecté pour un provider
Future<Map<String, dynamic>> adminCollectMonth({
  required String providerId,
  required String month, // 'YYYY-MM'
  String? note,
}) async {
  await ensureAuth();
  final r = await _authRetry(() async => await _dio.post(
        '/earnings/admin/collect-month',
        data: {'providerId': providerId, 'month': month, if (note != null) 'note': note},
      ));
  final payload = (r.data is Map) ? (r.data['data'] ?? r.data) : r.data;
  return (payload is Map) ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
}

// Annuler la collecte d’un mois pour un provider
Future<Map<String, dynamic>> adminUncollectMonth({
  required String providerId,
  required String month, // 'YYYY-MM'
}) async {
  await ensureAuth();
  final r = await _authRetry(() async => await _dio.post(
        '/earnings/admin/uncollect-month',
        data: {'providerId': providerId, 'month': month},
      ));
  final payload = (r.data is Map) ? (r.data['data'] ?? r.data) : r.data;
  return (payload is Map) ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
}

// COMPLETED du mois courant (depuis l’historique earnings)
Future<int> adminCountCompletedForCurrentMonth(String providerId) async {
  final rows = await adminHistoryMonthly(providerId: providerId, months: 1);
  if (rows.isEmpty) return 0;
  return _asInt(rows.first['COMPLETED']);
}

// Détails du mois courant par provider (due/collected depuis earnings)
Future<List<Map<String, dynamic>>> adminMonthDueByProvider() async {
  await ensureAuth();
  final approved = await listProviderApplications(status: 'approved', limit: 1000, offset: 0);
  final out = <Map<String, dynamic>>[];
  for (final raw in approved) {
    final p = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final pid = (p['id'] ?? '').toString();
    if (pid.isEmpty) continue;
    try {
      final rows = await adminHistoryMonthly(providerId: pid, months: 1);
      final row = rows.isNotEmpty ? rows.first : const <String, dynamic>{};
      out.add({
        'provider': p,
        'completed': _asInt(row['COMPLETED']),
        'dueDa': _asInt(row['dueDa']),
        'collectedDa': _asInt(row['collectedDa']),
        'netDa': _asInt(row['netDa']),
      });
    } catch (_) {
      // ignore
    }
  }
  return out;
}

// Somme globale du mois courant (due/collected)
Future<Map<String, dynamic>> adminCommissionSummary() async {
  final rows = await adminMonthDueByProvider();
  int due = 0, coll = 0;
  for (final r in rows) {
    due += _asInt(r['dueDa']);
    coll += _asInt(r['collectedDa']);
  }
  return {'totalDueMonthDa': due, 'totalCollectedMonthDa': coll};
}

// ---------------- Re-soumettre candidature (PRO) ----------------
Future<Map<String, dynamic>> reapplyMyProvider() async {
  await ensureAuth();
  final paths = <String>[
    '/providers/me/reapply',                  // Nest actuel (ProvidersController)
    '/providers/applications/me/reapply',     // variantes possibles
    '/providers/me/application/reapply',
    '/providers/reapply',
  ];

  DioException? last;
  for (final p in paths) {
    try {
      final r = await _authRetry(() async => await _dio.post(p));
      final data = (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      return (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      last = e;
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow; // autre erreur => on remonte
    }

    // fallback PATCH si POST non supporté
    try {
      final r = await _authRetry(() async => await _dio.patch(p));
      final data = (r.data is Map && r.data['data'] != null) ? r.data['data'] : r.data;
      return (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      last = e;
      if ((e.response?.statusCode ?? 0) == 404) continue; // on essaye le chemin suivant
    }
  }
  throw Exception(_extractMessage(last?.response?.data));
}


// ========================== FIN ADMIN (/earnings) ==========================



  // ---------------- Patients (fallback et version améliorée) ----------------

  Future<List<Map<String, dynamic>>> providerPatientsFallback({String? q}) async {
    await ensureAuth();
    final now = DateTime.now().toUtc();
    final from = DateTime.utc(now.year - 2, 1, 1);
    final rows = await providerAgenda(
      fromIso: from.toIso8601String(),
      toIso: now.toIso8601String(),
    );

    final byUser = <String, Map<String, dynamic>>{};
    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? '').toString();
      if (st != 'CONFIRMED' && st != 'COMPLETED') continue;

      final userMap = Map<String, dynamic>.from(m['user'] ?? {});
      final uid = (m['userId'] ?? userMap['id'] ?? '').toString();
      if (uid.isEmpty) continue;

      if (q != null && q.trim().isNotEmpty) {
        final needle = q.toLowerCase();
final hay =
  '${userMap['displayName'] ?? ''} ${userMap['firstName'] ?? ''} ${userMap['lastName'] ?? ''} ${userMap['email'] ?? ''} ${userMap['phone'] ?? ''}'
    .toLowerCase();
        if (!hay.contains(needle)) continue;
      }

      final entry = byUser.putIfAbsent(uid, () => {
            'user': userMap,
            'bookings': <Map<String, dynamic>>[],
            'pets': <Map<String, dynamic>>[],
          });

      (entry['bookings'] as List).add({
        'id': m['id'],
        'scheduledAt': m['scheduledAt'] ?? m['scheduled_at'],
        'status': st,
        'service': m['service'],
        'pet': m['pet'],
      });
    }

    final list = <Map<String, dynamic>>[];
    for (final v in byUser.values) {
      final bookings = (v['bookings'] as List).cast<Map<String, dynamic>>();
      bookings.sort((a, b) {
        final A = DateTime.tryParse((a['scheduledAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final B = DateTime.tryParse((b['scheduledAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return B.compareTo(A);
      });
      list.add({
        'user': v['user'],
        'bookings': bookings,
        'bookingsCount': bookings.length,
        'lastSeenAt': bookings.isNotEmpty ? bookings.first['scheduledAt'] : null,
        'pets': v['pets'],
      });
    }

    list.sort((a, b) {
      final A = DateTime.tryParse((a['lastSeenAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final B = DateTime.tryParse((b['lastSeenAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return B.compareTo(A);
    });

    return list;
  }

  Future<List<Map<String, dynamic>>> providerPatients({String? q}) async {
    await ensureAuth();

    final from = DateTime.utc(DateTime.now().year - 2, 1, 1);
    final rows = await providerAgenda(fromIso: from.toIso8601String());

    final byUser = <String, Map<String, dynamic>>{};

    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? '').toString();

      if (st != 'CONFIRMED' && st != 'COMPLETED') continue;

      final userMap = Map<String, dynamic>.from(m['user'] ?? {});
      final uid = (m['userId'] ?? userMap['id'] ?? userMap['email'] ?? '').toString();
      if (uid.isEmpty) continue;

      if (q != null && q.trim().isNotEmpty) {
        final needle = q.toLowerCase();
final hay = [
  userMap['displayName'] ?? '',
  userMap['firstName'] ?? '',
  userMap['lastName'] ?? '',
  userMap['email'] ?? '',
  userMap['phone'] ?? '',
].join(' ').toLowerCase();
        if (!hay.contains(needle)) continue;
      }

      final entry = byUser.putIfAbsent(uid, () => {
            'user': userMap,
            'bookings': <Map<String, dynamic>>[],
            'pets': <Map<String, dynamic>>[],
          });

      (entry['bookings'] as List).add({
        'id': m['id'],
        'scheduledAt': m['scheduledAt'] ?? m['scheduled_at'],
        'status': st,
        'service': m['service'],
        'pet': m['pet'],
      });
    }

    final list = <Map<String, dynamic>>[];
    for (final v in byUser.values) {
      final bookings = (v['bookings'] as List).cast<Map<String, dynamic>>();
      bookings.sort((a, b) {
        final A = DateTime.tryParse((a['scheduledAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final B = DateTime.tryParse((b['scheduledAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return B.compareTo(A);
      });
      list.add({
        'user': v['user'],
        'bookings': bookings,
        'bookingsCount': bookings.length,
        'lastSeenAt': bookings.isNotEmpty ? bookings.first['scheduledAt'] : null,
        'pets': v['pets'],
      });
    }

    list.sort((a, b) {
      final A = DateTime.tryParse((a['lastSeenAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final B = DateTime.tryParse((b['lastSeenAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return B.compareTo(A);
    });

    return list;
  }

  // --------------- Services publics d’un provider ---------------
  Future<List<dynamic>> listServices(String providerId) async {
    final res = await _dio.get('/providers/$providerId/services');
    final raw = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());

    // Normalisation forte
    return raw.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);

      final pr = m['price'];
      num? priceNum;
      if (pr is num) {
        priceNum = pr;
      } else if (pr is String) {
        priceNum = int.tryParse(pr) ?? double.tryParse(pr);
      }
      m['price'] = priceNum;

      m['description'] = (m['description'] ?? '').toString();
      m['title']       = (m['title'] ?? '').toString();
      m['id']          = (m['id'] ?? '').toString();
      m['providerId']  = (m['providerId'] ?? '').toString();

      final d = m['durationMin'];
      m['durationMin'] = (d is int) ? d : int.tryParse('$d') ?? 0;

      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getServiceDetails(String providerId, String serviceId) async {
    final list = await listServices(providerId);
    try {
      return list.cast<Map<String, dynamic>>()
                 .firstWhere((m) => (m['id'] ?? '').toString() == serviceId);
    } catch (_) {
      return null;
    }
  }

  // ========= Public Petshop Products =========

  /// Liste publique des produits d'une animalerie (accessibles aux utilisateurs)
  Future<List<Map<String, dynamic>>> listPublicProducts(String providerId) async {
    final paths = <String>[
      '/providers/$providerId/products',
      '/petshop/$providerId/products',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _dio.get(path);
        final data = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404 || code == 403) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  // ========= Petshop (PRO) =========

  /// Liste des produits pour l'animalerie connectée
  Future<List<Map<String, dynamic>>> myProducts() async {
    await ensureAuth();
    final paths = <String>[
      '/petshop/me/products',
      '/providers/me/products',
      '/products/me',
    ];

    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.get(path));
        final data = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404 || code == 405) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  Future<Map<String, dynamic>> createProduct({
    required String title,
    required int priceDa,
    required int stock,
    String? description,
    String? category,
    List<String>? imageUrls,
    bool active = true,
  }) async {
    await ensureAuth();
    final body = _dropNulls({
      'title': title,
      'priceDa': priceDa,
      'stock': stock,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'active': active,
    });

    final paths = <String>[
      '/petshop/me/products',
      '/providers/me/products',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.post(path, data: body));
        return _unwrap<Map<String, dynamic>>(res.data);
      } on DioException catch (e) {
        last = e;
        if ((e.response?.statusCode ?? 0) == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  Future<Map<String, dynamic>> updateProduct(
    String productId, {
    String? title,
    int? priceDa,
    int? stock,
    String? description,
    String? category,
    List<String>? imageUrls,
    bool? active,
  }) async {
    await ensureAuth();
    final body = _dropNulls({
      'title': title,
      'priceDa': priceDa,
      'stock': stock,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'active': active,
    });
    final paths = <String>[
      '/petshop/me/products/$productId',
      '/providers/me/products/$productId',
      '/products/$productId',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.patch(path, data: body));
        return _unwrap<Map<String, dynamic>>(res.data);
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  Future<void> deleteProduct(String productId) async {
    await ensureAuth();
    final paths = <String>[
      '/petshop/me/products/$productId',
      '/providers/me/products/$productId',
      '/products/$productId',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        await _authRetry(() async => await _dio.delete(path));
        return;
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  /// Liste des commandes d'animalerie
  Future<List<Map<String, dynamic>>> myPetshopOrders({String? status}) async {
    await ensureAuth();
    final paths = <String>[
      '/petshop/me/orders',
      '/providers/me/orders',
      '/orders/me',
    ];
    DioException? last;
    final params = <String, dynamic>{if (status != null && status.isNotEmpty) 'status': status};
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.get(path, queryParameters: params));
        final data = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404 || code == 405) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  Future<Map<String, dynamic>> getPetshopOrder(String orderId) async {
    await ensureAuth();
    final paths = <String>[
      '/petshop/me/orders/$orderId',
      '/providers/me/orders/$orderId',
      '/orders/$orderId',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.get(path));
        return _unwrap<Map<String, dynamic>>(res.data);
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  Future<Map<String, dynamic>> updatePetshopOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await ensureAuth();
    final body = {'status': status};
    final paths = <String>[
      '/petshop/me/orders/$orderId/status',
      '/providers/me/orders/$orderId/status',
      '/orders/$orderId/status',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.patch(path, data: body));
        return _unwrap<Map<String, dynamic>>(res.data);
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  /// Créer une commande (client)
  Future<Map<String, dynamic>> createPetshopOrder({
    required String providerId,
    required List<Map<String, dynamic>> items, // [{productId: String, quantity: int}]
    String? deliveryAddress,
    String? notes,
    String? phone,
    int? totalDa, // Not used - calculated server-side
  }) async {
    await ensureAuth();
    final body = {
      'providerId': providerId,
      'items': items,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final paths = <String>[
      '/petshop/orders',
      '/orders',
    ];
    DioException? last;
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.post(path, data: body));
        return _unwrap<Map<String, dynamic>>(res.data);
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }

  /// Liste des commandes du client (côté utilisateur)
  Future<List<Map<String, dynamic>>> myClientOrders({String? status}) async {
    await ensureAuth();
    final paths = <String>[
      '/orders/me',
      '/petshop/orders/me',
    ];
    DioException? last;
    final params = <String, dynamic>{if (status != null && status.isNotEmpty) 'status': status};
    for (final path in paths) {
      try {
        final res = await _authRetry(() async => await _dio.get(path, queryParameters: params));
        final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return [];
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        if (code == 404) continue;
        rethrow;
      }
    }
    throw Exception(_extractMessage(last?.response?.data));
  }
}