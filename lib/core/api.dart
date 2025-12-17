// lib/core/api.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kDefaultApiBase =
    String.fromEnvironment('API_BASE', defaultValue: 'https://api.vegece.com/api/v1');

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

  // Getter public pour permettre les appels directs (ex: daycare endpoints)
  Dio get dio => _dio;

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

  Future<Map<String, dynamic>> googleAuth({
    required String googleId,
    required String email,
    String? firstName,
    String? lastName,
    String? photoUrl,
  }) async {
    final res = await _dio.post('/auth/google', data: {
      'googleId': googleId,
      'email': email,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    final data = _unwrap<Map<String, dynamic>>(res.data);

    final access = (data['accessToken'] ?? data['token'] ?? '') as String;
    if (access.isEmpty) throw Exception('Token manquant');

    final refresh = (data['refreshToken'] ?? data['refresh_token'] ?? '') as String?;
    await setToken(access);
    await setRefreshToken(refresh);

    return data;
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
    final res = await _authRetry(() async => await _dio.get('/users/me'));
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
    final res = await _authRetry(() async => await _dio.patch('/users/me', data: body));
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
  /// Upload un fichier vers S3
  /// [folder] permet d'organiser les fichiers: 'avatars', 'pets', 'adopt', etc.
  Future<String> uploadLocalFile(File file, {String folder = 'uploads'}) async {
    await ensureAuth();

    final filename = file.path.split(Platform.pathSeparator).last;
    final ext = _extensionOf(filename);
    final mime = _mimeFromExtension(ext);

    // Priorité 1: Upload S3 via presign (production)
    try {
      final presign = await _authRetry(
        () async => await _dio.post('/uploads/presign', data: {
          'mimeType': mime,
          'folder': folder,
          'ext': ext,
        }),
      );
      final m = _unwrap<Map<String, dynamic>>(presign.data);
      final putUrl = (m['url'] ?? '') as String;
      if (putUrl.isNotEmpty) {
        final bytes = await file.readAsBytes();

        // Utiliser les headers requis retournés par le backend
        final requiredHeaders = (m['requiredHeaders'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString()))
            ?? {'Content-Type': mime};

        // IMPORTANT: Utiliser une instance Dio propre sans interceptors
        // et désactiver TOUS les headers automatiques pour ne pas casser la signature S3
        try {
          await Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 30),
          )).put(
            putUrl,
            data: bytes,
            options: Options(
              headers: requiredHeaders,
              contentType: mime,
              // Désactiver les headers automatiques de Dio
              followRedirects: false,
              validateStatus: (status) => status! < 400,
            ),
          );
          debugPrint('S3 upload SUCCESS for key: ${m['key']}');
        } catch (e) {
          debugPrint('S3 upload FAILED: $e');
          debugPrint('PUT URL: $putUrl');
          debugPrint('Headers: $requiredHeaders');
          rethrow;
        }

        // Confirmer l'upload pour définir l'ACL public-read (OVH)
        final needsConfirm = (m['needsConfirm'] ?? false) as bool;
        final key = (m['key'] ?? '') as String;
        if (needsConfirm && key.isNotEmpty) {
          try {
            await _authRetry(
              () async => await _dio.post('/uploads/confirm', data: {'key': key}),
            );
          } catch (e) {
            // Log mais ne pas faire échouer l'upload
            debugPrint('Failed to confirm upload ACL: $e');
          }
        }

        final publicUrl = (m['publicUrl'] ?? m['public_url'] ?? '') as String;
        if (publicUrl.isNotEmpty) return publicUrl;

        final bucket = (m['bucket'] ?? '') as String;
        final publicBase = const String.fromEnvironment('S3_PUBLIC_ENDPOINT', defaultValue: '');
        if (publicBase.isNotEmpty && bucket.isNotEmpty && key.isNotEmpty) {
          return '${publicBase.replaceAll(RegExp(r'/+$'), '')}/$bucket/$key';
        }
      }
    } on DioException catch (e) {
      // S3 presign a échoué - on remonte l'erreur au lieu de fallback silencieux
      debugPrint('S3 presign FAILED: ${e.response?.statusCode} - ${e.message}');
      rethrow;
    }

    // Si on arrive ici, presign n'a pas retourné de publicUrl valide
    throw DioException(
      requestOptions: RequestOptions(path: '/uploads/presign'),
      error: 'S3 presign n\'a pas retourné d\'URL publique',
    );
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
    final res = await _authRetry(() async => await _dio.get('/providers/me/availability'));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> setWeekly(List<Map<String, dynamic>> entries) async {
    await ensureAuth();
    await _authRetry(() async => await _dio.post('/providers/me/availability', data: {'entries': entries}));
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
  /// Le back gère l'expansion des liens Google Maps et l'extraction lat/lng.
  Future<Map<String, dynamic>> upsertMyProvider({
    required String displayName,
    String? bio,
    String? address,
    double? lat,
    double? lng,
    Map<String, dynamic>? specialties,
    bool forceReparse = false,
    String? timezone,
    String? avnCardFront,
    String? avnCardBack,
    String? avatarUrl,
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
      // si le front n'envoie pas lat/lng, le back recalcule depuis mapsUrl
      if (!forceReparse && _validCoord(lat)) 'lat': lat,
      if (!forceReparse && _validCoord(lng)) 'lng': lng,
      if (avnCardFront != null) 'avnCardFront': avnCardFront,
      if (avnCardBack != null) 'avnCardBack': avnCardBack,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
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
      final res = await _authRetry(() async => await _dio.get('/providers/me'));
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
    List<String>? petIds,
    String? clientNotes,
    String? endDateIso,
    int? commissionDa,
  }) async {
    await ensureAuth();
    final data = <String, dynamic>{
      'serviceId': serviceId,
      'scheduledAt': scheduledAtIso,
    };

    if (petIds != null && petIds.isNotEmpty) data['petIds'] = petIds;
    if (clientNotes != null && clientNotes.isNotEmpty) data['clientNotes'] = clientNotes;
    if (endDateIso != null) data['endDate'] = endDateIso;
    if (commissionDa != null) data['commissionDa'] = commissionDa;

    final res = await _dio.post('/bookings', data: data);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<List<dynamic>> myBookings() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/bookings/mine'));
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

  // --------------- Daycare Bookings (SÉPARÉ des bookings vétérinaires) ---------------

  /// Créer une réservation de garderie
  Future<Map<String, dynamic>> createDaycareBooking({
    required String petId,
    required String providerId,
    required String startDate,
    required String endDate,
    required int priceDa,
    String? notes,
  }) async {
    await ensureAuth();
    final res = await _dio.post('/daycare/bookings', data: {
      'petId': petId,
      'providerId': providerId,
      'startDate': startDate,
      'endDate': endDate,
      'priceDa': priceDa,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Récupérer mes réservations de garderie (client)
  Future<List<dynamic>> myDaycareBookings() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/my/bookings'));
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  /// Récupérer les réservations de ma garderie (provider)
  Future<List<dynamic>> myDaycareProviderBookings() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/provider/bookings'));
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  /// Annuler une réservation de garderie (client)
  Future<Map<String, dynamic>> cancelDaycareBooking(String bookingId) async {
    await ensureAuth();
    final res = await _dio.patch('/daycare/my/bookings/$bookingId/cancel');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Mettre à jour le statut d'une réservation de garderie (client)
  Future<Map<String, dynamic>> setDaycareBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await ensureAuth();
    final res = await _dio.patch('/daycare/bookings/$bookingId/status', data: {'status': status});
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Marquer l'arrivée de l'animal (drop-off) - provider
  Future<Map<String, dynamic>> markDaycareDropOff(String bookingId) async {
    await ensureAuth();
    final res = await _dio.patch('/daycare/bookings/$bookingId/drop-off');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Marquer le départ de l'animal (pickup) - provider
  Future<Map<String, dynamic>> markDaycarePickup(String bookingId) async {
    await ensureAuth();
    final res = await _dio.patch('/daycare/bookings/$bookingId/pickup');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Chercher un booking daycare actif pour un pet (scan QR garderie)
  Future<Map<String, dynamic>?> findActiveDaycareBookingForPet(String petId) async {
    try {
      final res = await _authRetry(() async => await _dio.get('/daycare/active-for-pet/$petId'));
      final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Confirmer la réception de l'animal à la garderie (après scan QR)
  /// Alias pour markDaycareDropOff - ANCIEN SYSTÈME
  Future<Map<String, dynamic>> confirmDaycareDropOff(String bookingId) async {
    return markDaycareDropOff(bookingId);
  }

  // --------------- Daycare Anti-fraude ---------------

  /// Client: Confirmer l'arrivée pour déposer l'animal (avec géoloc)
  Future<Map<String, dynamic>> clientConfirmDaycareDropOff(
    String bookingId, {
    String method = 'PROXIMITY',
    double? lat,
    double? lng,
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/client-confirm-drop',
          data: {'method': method, 'lat': lat, 'lng': lng},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Client: Confirmer l'arrivée pour récupérer l'animal (avec géoloc)
  Future<Map<String, dynamic>> clientConfirmDaycarePickup(
    String bookingId, {
    String method = 'PROXIMITY',
    double? lat,
    double? lng,
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/client-confirm-pickup',
          data: {'method': method, 'lat': lat, 'lng': lng},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Valider ou refuser le dépôt de l'animal
  Future<Map<String, dynamic>> proValidateDaycareDropOff(
    String bookingId, {
    required bool approved,
    String method = 'MANUAL',
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/pro-validate-drop',
          data: {'approved': approved, 'method': method},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Valider ou refuser le retrait de l'animal
  Future<Map<String, dynamic>> proValidateDaycarePickup(
    String bookingId, {
    required bool approved,
    String method = 'MANUAL',
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/pro-validate-pickup',
          data: {'approved': approved, 'method': method},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Obtenir les réservations en attente de validation
  Future<List<dynamic>> getDaycarePendingValidations() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/provider/pending-validations'));
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  /// Récupérer les détails d'une réservation daycare
  Future<Map<String, dynamic>> getDaycareBooking(String bookingId) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/bookings/$bookingId'));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Client: Obtenir le code OTP pour le dépôt
  Future<Map<String, dynamic>> getDaycareDropOtp(String bookingId) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/bookings/$bookingId/drop-otp'));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Client: Obtenir le code OTP pour le retrait
  Future<Map<String, dynamic>> getDaycarePickupOtp(String bookingId) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/bookings/$bookingId/pickup-otp'));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Valider par code OTP
  Future<Map<String, dynamic>> validateDaycareByOtp(
    String bookingId, {
    required String otp,
    required String phase, // 'drop' ou 'pickup'
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/validate-otp',
          data: {'otp': otp, 'phase': phase},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Client: Notifier qu'il est à proximité de la garderie
  Future<Map<String, dynamic>> notifyDaycareClientNearby(
    String bookingId, {
    double? lat,
    double? lng,
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/client-nearby',
          data: {'lat': lat, 'lng': lng},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Obtenir les clients à proximité
  Future<List<dynamic>> getDaycareNearbyClients() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/provider/nearby-clients'));
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  /// Client: Confirmer le retrait avec calcul frais de retard
  Future<Map<String, dynamic>> clientConfirmDaycarePickupWithLateFee(
    String bookingId, {
    String method = 'PROXIMITY',
    double? lat,
    double? lng,
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/client-confirm-pickup-late',
          data: {'method': method, 'lat': lat, 'lng': lng},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Calculer les frais de retard pour une réservation
  Future<Map<String, dynamic>> calculateDaycareLateFee(String bookingId) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/bookings/$bookingId/late-fee'));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Accepter ou refuser les frais de retard
  Future<Map<String, dynamic>> handleDaycareLateFee(
    String bookingId, {
    required bool accept,
    String? note,
  }) async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.post(
          '/daycare/bookings/$bookingId/handle-late-fee',
          data: {'accept': accept, 'note': note},
        ));
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Pro: Obtenir les bookings avec frais de retard en attente
  Future<List<dynamic>> getDaycarePendingLateFees() async {
    await ensureAuth();
    final res = await _authRetry(() async => await _dio.get('/daycare/provider/pending-late-fees'));
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
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
    String? birthDateIso,
    String? microchipNumber,
    String? allergies,
    String? description,
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
          if (birthDateIso != null) 'birthDate': _isoDateOrUtcMidnight(birthDateIso),
          if (microchipNumber != null) 'microchipNumber': microchipNumber,
          if (allergies != null) 'allergiesNotes': allergies,
          if (description != null) 'description': description,
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
      final res = await _authRetry(() async => await _dio.get('/pets/mine'));
      return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res2 = await _authRetry(() async => await _dio.get('/pets'));
        return _unwrap<List<dynamic>>(res2.data, map: (d) => (d as List).cast<dynamic>());
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePet({
    required String petId,
    String? name,
    String? breed,
    String? color,
    String? photoUrl,
    double? weightKg,
    String? gender,
    String? neuteredAtIso,
    String? birthDateIso,
    String? microchipNumber,
    String? allergies,
    String? description,
    String? country,
    String? idNumber,
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
      if (birthDateIso != null) 'birthDate': _isoDateOrUtcMidnight(birthDateIso),
      if (microchipNumber != null) 'microchipNumber': microchipNumber,
      if (allergies != null) 'allergiesNotes': allergies,
      if (description != null) 'description': description,
      if (country != null) 'country': country,
      if (idNumber != null) 'idNumber': idNumber,
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

  // --------------- Medical Records ---------------

  Future<List<dynamic>> getMedicalRecords(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/medical-records');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createMedicalRecord(
    String petId, {
    required String type,
    required String title,
    required String dateIso,
    String? description,
    String? vetName,
    String? notes,
    List<String>? images,
    double? weightKg,
    double? temperatureC,
    int? heartRate,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'type': type,
      'title': title,
      'date': dateIso,
      if (description != null) 'description': description,
      if (vetName != null) 'vetName': vetName,
      if (notes != null) 'notes': notes,
      if (images != null) 'images': images,
      if (weightKg != null) 'weightKg': weightKg,
      if (temperatureC != null) 'temperatureC': temperatureC,
      if (heartRate != null) 'heartRate': heartRate,
    };
    final res = await _dio.post('/pets/$petId/medical-records', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> updateMedicalRecord(
    String petId,
    String recordId, {
    String? type,
    String? title,
    String? dateIso,
    String? description,
    String? vetName,
    String? notes,
    List<String>? images,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (dateIso != null) 'date': dateIso,
      if (description != null) 'description': description,
      if (vetName != null) 'vetName': vetName,
      if (notes != null) 'notes': notes,
      if (images != null) 'images': images,
    };
    final res = await _dio.patch('/pets/$petId/medical-records/$recordId', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<bool> deleteMedicalRecord(String petId, String recordId) async {
    await ensureAuth();
    try {
      await _dio.delete('/pets/$petId/medical-records/$recordId');
      return true;
    } catch (_) {
      return false;
    }
  }

  // --------------- Pet Access Token (QR Code) ---------------

  Future<Map<String, dynamic>> generatePetAccessToken(String petId, {int expirationMinutes = 30}) async {
    await ensureAuth();
    final res = await _dio.post('/pets/$petId/access-token', data: {
      'expirationMinutes': expirationMinutes,
    });
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> getPetByToken(String token) async {
    await ensureAuth();
    final res = await _dio.get('/pets/by-token/$token');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Sync scanned pet token with website (Flutter -> Website sync)
  Future<void> setScannedPet(String token) async {
    await ensureAuth();
    await _dio.post('/providers/me/scanned-pet', data: {'token': token});
  }

  Future<Map<String, dynamic>> createMedicalRecordByToken(
    String token, {
    required String type,
    required String title,
    required String dateIso,
    required String vetName,
    String? description,
    String? notes,
    List<String>? images,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'type': type,
      'title': title,
      'date': dateIso,
      'vetName': vetName,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (images != null) 'images': images,
    };
    final res = await _dio.post('/pets/by-token/$token/medical-records', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Create vaccination via token (vet access)
  Future<Map<String, dynamic>> createVaccinationByToken(
    String token, {
    required String name,
    required String dateIso,
    String? nextDueDateIso,
    String? batchNumber,
    String? vetName,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      'date': dateIso,
      if (nextDueDateIso != null) 'nextDueDate': nextDueDateIso,
      if (batchNumber != null) 'batchNumber': batchNumber,
      if (vetName != null) 'veterinarian': vetName,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/by-token/$token/vaccinations', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Create treatment via token (vet access)
  Future<Map<String, dynamic>> createTreatmentByToken(
    String token, {
    required String name,
    required String startDateIso,
    String? dosage,
    String? frequency,
    String? endDateIso,
    bool isActive = true,
    String? notes,
    List<String>? attachments,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      'startDate': startDateIso,
      'isActive': isActive,
      if (dosage != null) 'dosage': dosage,
      if (frequency != null) 'frequency': frequency,
      if (endDateIso != null) 'endDate': endDateIso,
      if (notes != null) 'notes': notes,
      if (attachments != null) 'attachments': attachments,
    };
    final res = await _dio.post('/pets/by-token/$token/treatments', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Create weight record via token (vet access)
  Future<Map<String, dynamic>> createWeightRecordByToken(
    String token, {
    required double weightKg,
    required String dateIso,
    String? context,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'weightKg': weightKg,
      'date': dateIso,
      if (context != null) 'context': context,
    };
    final res = await _dio.post('/pets/by-token/$token/weight-records', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Create disease via token (vet access)
  Future<Map<String, dynamic>> createDiseaseByToken(
    String token, {
    required String name,
    String? description,
    String? status,
    String? severity,
    String? symptoms,
    String? treatment,
    String? notes,
    List<String>? images,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (symptoms != null) 'symptoms': symptoms,
      if (treatment != null) 'treatment': treatment,
      if (notes != null) 'notes': notes,
      if (images != null) 'images': images,
    };
    final res = await _dio.post('/pets/by-token/$token/diseases', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// List diseases via token (vet access)
  Future<List<dynamic>> listDiseasesByToken(String token) async {
    await ensureAuth();
    final res = await _dio.get('/pets/by-token/$token/diseases');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  /// Get disease detail via token (vet access)
  Future<Map<String, dynamic>> getDiseaseByToken(String token, String diseaseId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/by-token/$token/diseases/$diseaseId');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  /// Add disease progress entry via token (vet access)
  Future<Map<String, dynamic>> addDiseaseProgressByToken(
    String token,
    String diseaseId, {
    required String notes,
    String? severity,
    String? treatmentUpdate,
    List<String>? images,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'notes': notes,
      if (severity != null) 'severity': severity,
      if (treatmentUpdate != null) 'treatmentUpdate': treatmentUpdate,
      if (images != null) 'images': images,
    };
    final res = await _dio.post('/pets/by-token/$token/diseases/$diseaseId/progress', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  // --------------- Weight Records ---------------

  Future<List<dynamic>> getWeightRecords(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/weight-records');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createWeightRecord(
    String petId, {
    required double weightKg,
    required String dateIso,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'weightKg': weightKg,
      'date': dateIso,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/$petId/weight-records', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteWeightRecord(String petId, String recordId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/weight-records/$recordId');
  }

  // --------------- Health Statistics ---------------

  Future<Map<String, dynamic>> getHealthStats(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/health-stats');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  // --------------- Vaccinations ---------------

  Future<List<dynamic>> getVaccinations(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/vaccinations');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createVaccination(
    String petId, {
    required String name,
    required String dateIso,
    String? nextDueDateIso,
    String? batchNumber,
    String? vetId,
    String? vetName,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      'date': dateIso,
      if (nextDueDateIso != null) 'nextDueDate': nextDueDateIso,
      if (batchNumber != null) 'batchNumber': batchNumber,
      if (vetId != null) 'vetId': vetId,
      if (vetName != null) 'vetName': vetName,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/$petId/vaccinations', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteVaccination(String petId, String vaccinationId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/vaccinations/$vaccinationId');
  }

  // --------------- Treatments ---------------

  Future<List<dynamic>> getTreatments(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/treatments');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createTreatment(
    String petId, {
    required String name,
    required String startDateIso,
    String? dosage,
    String? frequency,
    String? endDateIso,
    bool isActive = true,
    String? notes,
    List<String>? attachments,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      'startDate': startDateIso,
      'isActive': isActive,
      if (dosage != null) 'dosage': dosage,
      if (frequency != null) 'frequency': frequency,
      if (endDateIso != null) 'endDate': endDateIso,
      if (notes != null) 'notes': notes,
      if (attachments != null) 'attachments': attachments,
    };
    final res = await _dio.post('/pets/$petId/treatments', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> updateTreatment(
    String petId,
    String treatmentId, {
    String? name,
    String? dosage,
    String? frequency,
    String? startDateIso,
    String? endDateIso,
    bool? isActive,
    String? notes,
    List<String>? attachments,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (dosage != null) 'dosage': dosage,
      if (frequency != null) 'frequency': frequency,
      if (startDateIso != null) 'startDate': startDateIso,
      if (endDateIso != null) 'endDate': endDateIso,
      if (isActive != null) 'isActive': isActive,
      if (notes != null) 'notes': notes,
      if (attachments != null) 'attachments': attachments,
    };
    final res = await _dio.patch('/pets/$petId/treatments/$treatmentId', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteTreatment(String petId, String treatmentId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/treatments/$treatmentId');
  }

  // --------------- Allergies ---------------

  Future<List<dynamic>> getAllergies(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/allergies');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createAllergy(
    String petId, {
    required String type,
    required String allergen,
    String? severity,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'type': type,
      'allergen': allergen,
      if (severity != null) 'severity': severity,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/$petId/allergies', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteAllergy(String petId, String allergyId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/allergies/$allergyId');
  }

  // --------------- Preventive Care ---------------

  Future<List<dynamic>> getPreventiveCare(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/preventive-care');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> createPreventiveCare(
    String petId, {
    required String type,
    required String lastDateIso,
    String? nextDueDateIso,
    String? product,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'type': type,
      'lastDate': lastDateIso,
      if (nextDueDateIso != null) 'nextDueDate': nextDueDateIso,
      if (product != null) 'product': product,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/$petId/preventive-care', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> updatePreventiveCare(
    String petId,
    String careId, {
    String? type,
    String? lastDateIso,
    String? nextDueDateIso,
    String? product,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (type != null) 'type': type,
      if (lastDateIso != null) 'lastDate': lastDateIso,
      if (nextDueDateIso != null) 'nextDueDate': nextDueDateIso,
      if (product != null) 'product': product,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.patch('/pets/$petId/preventive-care/$careId', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deletePreventiveCare(String petId, String careId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/preventive-care/$careId');
  }

  // --------------- Disease Tracking ---------------

  Future<List<dynamic>> getDiseases(String petId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/diseases');
    return _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  }

  Future<Map<String, dynamic>> getDisease(String petId, String diseaseId) async {
    await ensureAuth();
    final res = await _dio.get('/pets/$petId/diseases/$diseaseId');
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> createDisease(
    String petId, {
    required String name,
    required String diagnosisDateIso,
    String? description,
    String status = 'ONGOING',
    String? severity,
    String? curedDateIso,
    String? vetId,
    String? vetName,
    String? symptoms,
    String? treatment,
    List<String>? images,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'name': name,
      'diagnosisDate': diagnosisDateIso,
      'status': status,
      if (description != null) 'description': description,
      if (severity != null) 'severity': severity,
      if (curedDateIso != null) 'curedDate': curedDateIso,
      if (vetId != null) 'vetId': vetId,
      if (vetName != null) 'vetName': vetName,
      if (symptoms != null) 'symptoms': symptoms,
      if (treatment != null) 'treatment': treatment,
      if (images != null) 'images': images,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.post('/pets/$petId/diseases', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> updateDisease(
    String petId,
    String diseaseId, {
    String? name,
    String? description,
    String? status,
    String? severity,
    String? diagnosisDateIso,
    String? curedDateIso,
    String? vetId,
    String? vetName,
    String? symptoms,
    String? treatment,
    List<String>? images,
    String? notes,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (diagnosisDateIso != null) 'diagnosisDate': diagnosisDateIso,
      if (curedDateIso != null) 'curedDate': curedDateIso,
      if (vetId != null) 'vetId': vetId,
      if (vetName != null) 'vetName': vetName,
      if (symptoms != null) 'symptoms': symptoms,
      if (treatment != null) 'treatment': treatment,
      if (images != null) 'images': images,
      if (notes != null) 'notes': notes,
    };
    final res = await _dio.patch('/pets/$petId/diseases/$diseaseId', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteDisease(String petId, String diseaseId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/diseases/$diseaseId');
  }

  Future<Map<String, dynamic>> addDiseaseProgress(
    String petId,
    String diseaseId, {
    required String notes,
    String? dateIso,
    List<String>? images,
    String? severity,
    String? treatmentUpdate,
  }) async {
    await ensureAuth();
    final body = <String, dynamic>{
      'notes': notes,
      if (dateIso != null) 'date': dateIso,
      if (images != null) 'images': images,
      if (severity != null) 'severity': severity,
      if (treatmentUpdate != null) 'treatmentUpdate': treatmentUpdate,
    };
    final res = await _dio.post('/pets/$petId/diseases/$diseaseId/progress', data: body);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<void> deleteDiseaseProgress(String petId, String diseaseId, String entryId) async {
    await ensureAuth();
    await _dio.delete('/pets/$petId/diseases/$diseaseId/progress/$entryId');
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
  required String title,
  String? animalName,
  required String species,
  String sex = 'unknown',
  int? ageMonths,
  String? city,
  double? lat,
  double? lng,
  String? description,
  required List<String> photos,
}) async {
  await ensureAuth();
  final body = <String, dynamic>{
    'title': title,
    if (animalName != null && animalName.trim().isNotEmpty) 'animalName': animalName.trim(),
    'species': species,
    if (sex.isNotEmpty) 'sex': sex,
    if (ageMonths != null && ageMonths > 0) 'ageMonths': ageMonths,
    if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
    'images': photos.asMap().entries.map((e) => {
      'url': e.value,
      'order': e.key,
    }).toList(),
  };
  final res = await _authRetry(() async => await _dio.post('/adopt/posts', data: body));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// AUTH: éditer un post (propriétaire)
Future<Map<String, dynamic>> updateAdoptPost(
  String postId, {
  String? title,
  String? animalName,
  String? species,
  String? sex,
  int? ageMonths,
  String? city,
  double? lat,
  double? lng,
  String? description,
  List<String>? photos,
}) async {
  await ensureAuth();
  final body = <String, dynamic>{
    if (title != null) 'title': title,
    if (animalName != null) 'animalName': animalName,
    if (species != null) 'species': species,
    if (sex != null) 'sex': sex,
    if (ageMonths != null) 'ageMonths': ageMonths,
    if (city != null) 'city': city,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (description != null) 'description': description,
    if (photos != null) 'images': photos.asMap().entries.map((e) => {
      'url': e.value,
      'order': e.key,
    }).toList(),
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

// AUTH: récupérer les conversations pour un post (pour choisir l'adoptant)
Future<List<Map<String, dynamic>>> getAdoptPostConversations(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/posts/$postId/conversations'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// AUTH: marquer un post comme adopté
Future<Map<String, dynamic>> markAdoptPostAsAdopted(String postId, {String? adoptedById}) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
        '/adopt/posts/$postId/adopted',
        data: adoptedById != null ? {'adoptedById': adoptedById} : {},
      ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// AUTH: récupérer mes adoptions en attente de création de profil pet
Future<List<Map<String, dynamic>>> myPendingPetCreation() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/pending-pet-creation'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// AUTH: marquer qu'un profil pet a été créé pour une adoption
Future<Map<String, dynamic>> markAdoptPetProfileCreated(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post('/adopt/posts/$postId/mark-pet-created'));
  return _unwrap<Map<String, dynamic>>(res.data);
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

// GET /adopt/my/quotas - Quotas restants
Future<Map<String, dynamic>> adoptMyQuotas() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/quotas'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/posts/:id/adopted - Marquer comme adopté
Future<Map<String, dynamic>> adoptMarkAsAdopted(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post('/adopt/posts/$postId/adopted'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// GET /adopt/my/requests/incoming - Demandes reçues
Future<List<Map<String, dynamic>>> adoptMyIncomingRequests() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/requests/incoming'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// GET /adopt/my/requests/outgoing - Demandes envoyées
Future<List<Map<String, dynamic>>> adoptMyOutgoingRequests() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/requests/outgoing'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// POST /adopt/requests/:id/accept - Accepter demande
Future<Map<String, dynamic>> adoptAcceptRequest(String requestId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post('/adopt/requests/$requestId/accept'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/requests/:id/reject - Refuser demande
Future<Map<String, dynamic>> adoptRejectRequest(String requestId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post('/adopt/requests/$requestId/reject'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// GET /adopt/my/conversations - Liste conversations
Future<List<Map<String, dynamic>>> adoptMyConversations() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/my/conversations'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// GET /adopt/conversations/:id/messages - Messages d'une conversation
Future<Map<String, dynamic>> adoptGetConversationMessages(String conversationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/adopt/conversations/$conversationId/messages'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/conversations/:id/messages - Envoyer message
Future<Map<String, dynamic>> adoptSendMessage(String conversationId, String content) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
    '/adopt/conversations/$conversationId/messages',
    data: {'content': content},
  ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/conversations/:id/confirm-adoption - Confirmer l'adoption
Future<Map<String, dynamic>> adoptConfirmAdoption(String conversationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
    '/adopt/conversations/$conversationId/confirm-adoption',
  ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/conversations/:id/decline-adoption - Refuser l'adoption
Future<Map<String, dynamic>> adoptDeclineAdoption(String conversationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
    '/adopt/conversations/$conversationId/decline-adoption',
  ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/conversations/:id/hide - Masquer une conversation (soft delete)
Future<Map<String, dynamic>> adoptHideConversation(String conversationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
    '/adopt/conversations/$conversationId/hide',
  ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// POST /adopt/conversations/:id/report - Signaler une conversation
Future<Map<String, dynamic>> adoptReportConversation(String conversationId, String reason) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post(
    '/adopt/conversations/$conversationId/report',
    data: {'reason': reason},
  ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// ===================== Notifications =====================

// GET /notifications - Récupérer toutes les notifications
Future<List<Map<String, dynamic>>> getNotifications() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/notifications'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// GET /notifications/unread/count - Compter les notifications non lues
Future<int> getUnreadNotificationsCount() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/notifications/unread/count'));
  final data = _unwrap<Map<String, dynamic>>(res.data);
  return (data['count'] as num?)?.toInt() ?? 0;
}

// PATCH /notifications/:id/read - Marquer comme lu
Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/notifications/$notificationId/read'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /notifications/read-all - Tout marquer comme lu
Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/notifications/read-all'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// DELETE /notifications/:id - Supprimer une notification
Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.delete('/notifications/$notificationId'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// DELETE /notifications - Supprimer toutes les notifications
Future<Map<String, dynamic>> deleteAllNotifications() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.delete('/notifications'));
  return _unwrap<Map<String, dynamic>>(res.data);
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
Future<Map<String, dynamic>> adminAdoptReject(String postId, {List<String>? reasons, String? note}) async {
  await ensureAuth();
  final body = <String, dynamic>{};
  if (reasons != null && reasons.isNotEmpty) body['reasons'] = reasons;
  if (note != null && note.trim().isNotEmpty) body['note'] = note.trim();

  final res = await _authRetry(() async => await _dio.patch(
        '/admin/adopt/posts/$postId/reject',
        data: body,
      ));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /admin/adopt/posts/:id/archive
Future<Map<String, dynamic>> adminAdoptArchive(String postId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/admin/adopt/posts/$postId/archive'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// PATCH /admin/adopt/posts/approve-all
Future<Map<String, dynamic>> adminAdoptApproveAll() async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.patch('/admin/adopt/posts/approve-all'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// GET /admin/adopt/conversations - Récupérer toutes les conversations (admin)
Future<List<Map<String, dynamic>>> adminAdoptGetConversations({int limit = 50}) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get(
    '/admin/adopt/conversations',
    queryParameters: {'limit': limit},
  ));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// GET /admin/adopt/conversations/:id - Détails d'une conversation (admin)
Future<Map<String, dynamic>> adminAdoptGetConversationDetails(String conversationId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/admin/adopt/conversations/$conversationId'));
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
}) {
  // Parse age string to months for new API
  int? ageMonths;
  if (age != null && age.isNotEmpty) {
    final ageText = age.toLowerCase();
    final monthsMatch = RegExp(r'(\d+)\s*mois').firstMatch(ageText);
    final yearsMatch = RegExp(r'(\d+)\s*an').firstMatch(ageText);
    if (monthsMatch != null) {
      ageMonths = int.tryParse(monthsMatch.group(1)!);
    } else if (yearsMatch != null) {
      final years = int.tryParse(yearsMatch.group(1)!);
      if (years != null) ageMonths = years * 12;
    }
  }

  // Convert old sex format to new
  String newSex = sex == 'M' ? 'male' : (sex == 'F' ? 'female' : 'unknown');

  return createAdoptPost(
    title: petName, // Use petName as title for legacy calls
    animalName: petName,
    species: species,
    sex: newSex,
    ageMonths: ageMonths,
    city: city,
    lat: lat,
    lng: lng,
    description: desc,
    photos: photos,
  );
}

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

/// Admin: Statistiques de traçabilité par provider (taux d'annulation, confirmation, etc.)
Future<Map<String, dynamic>> adminTraceabilityStats({String? from, String? to}) async {
  await ensureAuth();
  final params = <String, String>{};
  if (from != null) params['from'] = from;
  if (to != null) params['to'] = to;
  final res = await _authRetry(() async => await _dio.get(
    '/bookings/admin/traceability',
    queryParameters: params.isEmpty ? null : params,
  ));
  return _unwrap<Map<String, dynamic>>(res.data, map: (d) => Map<String, dynamic>.from(d as Map));
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


// ========================== ADMIN (Users Management) ==========================

// Admin: reset quotas adoption d'un utilisateur
Future<Map<String, dynamic>> adminResetUserAdoptQuotas(String userId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.post('/users/$userId/reset-adopt-quotas'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// GET /users/:id/quotas - Get user quotas (admin)
Future<Map<String, dynamic>> adminGetUserQuotas(String userId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/users/$userId/quotas'));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// GET /users/:id/adopt-conversations - Get user adoption conversations (admin)
Future<List<Map<String, dynamic>>> adminGetUserAdoptConversations(String userId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/users/$userId/adopt-conversations'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// GET /users/:id/adopt-posts - Get all user adoption posts (admin)
Future<List<Map<String, dynamic>>> adminGetUserAdoptPosts(String userId) async {
  await ensureAuth();
  final res = await _authRetry(() async => await _dio.get('/users/$userId/adopt-posts'));
  final list = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// Admin: modifier les informations d'un utilisateur
Future<Map<String, dynamic>> adminUpdateUser(String userId, {
  String? firstName,
  String? lastName,
  String? phone,
  String? email,
  String? city,
  double? lat,
  double? lng,
  String? role,
}) async {
  await ensureAuth();
  final body = <String, dynamic>{};
  if (firstName != null) body['firstName'] = firstName;
  if (lastName != null) body['lastName'] = lastName;
  if (phone != null) body['phone'] = phone;
  if (email != null) body['email'] = email;
  if (city != null) body['city'] = city;
  if (lat != null) body['lat'] = lat;
  if (lng != null) body['lng'] = lng;
  if (role != null) body['role'] = role;

  final res = await _authRetry(() async => await _dio.patch('/users/$userId', data: body));
  return _unwrap<Map<String, dynamic>>(res.data);
}

// ========================== FIN ADMIN (Users) ==========================


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

  // --------------- Mes Services (création/modification) ---------------
  Future<Map<String, dynamic>> createService({
    required String title,
    required int durationMin,
    required int price,
    String? description,
  }) async {
    await ensureAuth();
    final res = await _dio.post('/providers/me/services', data: {
      'title': title,
      'durationMin': durationMin,
      'price': price,
      if (description != null) 'description': description,
    });
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<Map<String, dynamic>> updateService({
    required String serviceId,
    String? title,
    int? durationMin,
    int? price,
    String? description,
  }) async {
    await ensureAuth();
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (durationMin != null) data['durationMin'] = durationMin;
    if (price != null) data['price'] = price;
    if (description != null) data['description'] = description;

    final res = await _dio.patch('/providers/me/services/$serviceId', data: data);
    return _unwrap<Map<String, dynamic>>(res.data);
  }

  Future<List<Map<String, dynamic>>> listMyServices() async {
    await ensureAuth();
    final res = await _dio.get('/providers/me/services');
    final raw = _unwrap<List<dynamic>>(res.data, map: (d) => (d as List).cast<dynamic>());
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  // ==================== NOUVEAU: Système de Confirmation ====================

  /// Chercher un booking actif pour un pet (scan QR vet)
  Future<Map<String, dynamic>?> findActiveBookingForPet(String petId) async {
    try {
      final res = await _authRetry(() async => await _dio.get('/bookings/active-for-pet/$petId'));
      final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// PRO confirme un booking (après scan QR ou manuellement)
  /// @param method - 'QR_SCAN' | 'SIMPLE' | 'AUTO' (défaut: AUTO)
  Future<Map<String, dynamic>> proConfirmBooking(String bookingId, {String method = 'AUTO'}) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/pro-confirm',
      data: {'method': method},
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT demande confirmation (via popup avis)
  Future<Map<String, dynamic>> clientRequestConfirmation({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/client-confirm',
      data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT dit "je n'y suis pas allé"
  Future<Map<String, dynamic>> clientCancelBooking(String bookingId) async {
    final res = await _authRetry(() async => await _dio.post('/bookings/$bookingId/client-cancel'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// PRO valide ou refuse la confirmation client
  Future<Map<String, dynamic>> proValidateClientConfirmation({
    required String bookingId,
    required bool approved,
  }) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/pro-validate',
      data: {'approved': approved},
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Liste des bookings en attente de validation par le pro
  Future<List<dynamic>> getPendingValidations() async {
    final res = await _authRetry(() async => await _dio.get('/bookings/provider/me/pending-validations'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    if (data is List) return data;
    return [];
  }

  /// Alias: Client confirme le RDV (avec optionnellement un avis)
  Future<Map<String, dynamic>> clientConfirmBooking({
    required String bookingId,
    int? rating,
    String? comment,
  }) async {
    return clientRequestConfirmation(
      bookingId: bookingId,
      rating: rating ?? 5,
      comment: comment,
    );
  }

  /// Alias: Pro valide manuellement le RDV (approuve la confirmation client)
  Future<Map<String, dynamic>> proValidateBooking(String bookingId) async {
    return proValidateClientConfirmation(bookingId: bookingId, approved: true);
  }

  /// Récupère le nombre de RDV en attente de validation
  Future<int> getPendingValidationsCount() async {
    final list = await getPendingValidations();
    return list.length;
  }

  // ==================== CHECK-IN GÉOLOCALISÉ ====================

  /// CLIENT: Vérifier si proche du cabinet (pour afficher page confirmation)
  Future<Map<String, dynamic>> checkBookingProximity({
    required String bookingId,
    required double lat,
    required double lng,
  }) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/check-proximity',
      data: {'lat': lat, 'lng': lng},
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT: Faire check-in (enregistre la position GPS)
  Future<Map<String, dynamic>> clientCheckin({
    required String bookingId,
    required double lat,
    required double lng,
  }) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/checkin',
      data: {'lat': lat, 'lng': lng},
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT: Confirmer avec une méthode spécifique (SIMPLE, QR_SCAN)
  Future<Map<String, dynamic>> clientConfirmWithMethod({
    required String bookingId,
    required String method, // 'SIMPLE' | 'QR_SCAN'
    int? rating,
    String? comment,
  }) async {
    final res = await _authRetry(() async => await _dio.post(
      '/bookings/$bookingId/confirm-with-method',
      data: {
        'method': method,
        if (rating != null) 'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    ));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  // ==================== SYSTÈME DE CONFIANCE (ANTI-TROLL) ====================

  /// CLIENT: Vérifier si l'utilisateur peut réserver
  /// Retourne { canBook, reason?, trustStatus, isFirstBooking?, restrictedUntil? }
  Future<Map<String, dynamic>> checkUserCanBook() async {
    final res = await _authRetry(() async => await _dio.get('/bookings/me/trust-status'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT: Vérifier si l'utilisateur peut annuler un RDV
  /// Retourne { canCancel, reason?, isNoShow? }
  Future<Map<String, dynamic>> checkUserCanCancel(String bookingId) async {
    final res = await _authRetry(() async => await _dio.get('/bookings/$bookingId/can-cancel'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// CLIENT: Vérifier si l'utilisateur peut modifier un RDV
  /// Retourne { canReschedule, reason? }
  Future<Map<String, dynamic>> checkUserCanReschedule(String bookingId) async {
    final res = await _authRetry(() async => await _dio.get('/bookings/$bookingId/can-reschedule'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// PRO: Récupérer les infos de confiance d'un client
  /// Retourne { trustStatus, isFirstBooking, noShowCount, totalCompletedBookings }
  Future<Map<String, dynamic>> getUserTrustInfo(String userId) async {
    final res = await _authRetry(() async => await _dio.get('/bookings/user/$userId/trust-info'));
    final data = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    return Map<String, dynamic>.from(data as Map);
  }
}