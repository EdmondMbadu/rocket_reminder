import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'models.dart';
import 'rocket_goals_bridge_base.dart';

class _FirebaseRestBridge implements RocketGoalsBridge {
  static const String _firebaseApiKey = String.fromEnvironment(
    'ROCKET_GOALS_FIREBASE_API_KEY',
  );
  static const String _legacyApiKey = String.fromEnvironment(
    'ROCKET_GOALS_API_KEY',
  );
  static const String _projectId = 'rocket-prompt';
  static const String _functionsOrigin = String.fromEnvironment(
    'ROCKET_GOALS_FUNCTIONS_ORIGIN',
  );

  static String get _apiKey =>
      _firebaseApiKey.isNotEmpty ? _firebaseApiKey : _legacyApiKey;

  @override
  Future<void> sendPasswordReset(String email) async {
    await _postJson(_identityUri('accounts:sendOobCode'), <String, dynamic>{
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  @override
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  }) async {
    final authPayload = await _postJson(
      _identityUri('accounts:signInWithPassword'),
      <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      },
    );

    final credentials = RemoteCredentials(
      userId: authPayload['localId'] as String? ?? '',
      idToken: authPayload['idToken'] as String? ?? '',
      refreshToken: authPayload['refreshToken'] as String? ?? '',
      email: authPayload['email'] as String? ?? email.trim(),
    );

    final accountInfo = await _lookupAccount(credentials.idToken);
    final verified = accountInfo['emailVerified'] as bool? ?? false;
    if (!verified) {
      throw const BridgeException(
        'Please verify your email to log in. The mobile app follows the same rule as Rocket Goals.',
      );
    }

    final displayName = accountInfo['displayName'] as String? ?? '';
    final inferredNames = _splitName(displayName, credentials.email);
    final profile = await _loadOrCreateProfile(
      credentials: credentials,
      firstName: inferredNames.$1,
      lastName: inferredNames.$2,
      email: credentials.email,
    );

    return _bundleFromProfile(
      credentials: credentials,
      profile: profile,
      emailVerified: true,
      fallbackFirstName: inferredNames.$1,
      fallbackLastName: inferredNames.$2,
    );
  }

  @override
  Future<LinkedAccountBundle> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final authPayload = await _postJson(
      _identityUri('accounts:signUp'),
      <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      },
    );

    final credentials = RemoteCredentials(
      userId: authPayload['localId'] as String? ?? '',
      idToken: authPayload['idToken'] as String? ?? '',
      refreshToken: authPayload['refreshToken'] as String? ?? '',
      email: authPayload['email'] as String? ?? email.trim(),
    );

    await _patchDocument(
      collection: 'userProfiles',
      documentId: credentials.userId,
      idToken: credentials.idToken,
      values: <String, dynamic>{
        'id': credentials.userId,
        'userId': credentials.userId,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': credentials.email,
        'createdAt': DateTime.now().toUtc(),
        'goalLockAccessGranted': false,
        'goalLockIntroOfferUsed': false,
      },
    );

    await _postJson(_identityUri('accounts:sendOobCode'), <String, dynamic>{
      'requestType': 'VERIFY_EMAIL',
      'idToken': credentials.idToken,
    });

    return LinkedAccountBundle(
      account: UserAccount(
        userId: credentials.userId,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: credentials.email,
        mode: ExperienceMode.linked,
        emailVerified: false,
        goalLockAccessGranted: false,
      ),
      credentials: credentials,
      importedGoal: null,
      notice:
          'Account created. Verify your email, then complete payment to unlock Goal Lock.',
    );
  }

  @override
  Future<LinkedAccountBundle> refreshAccount({
    required RemoteCredentials credentials,
  }) async {
    final accountInfo = await _lookupAccount(credentials.idToken);
    final verified = accountInfo['emailVerified'] as bool? ?? false;
    final displayName = accountInfo['displayName'] as String? ?? '';
    final inferredNames = _splitName(displayName, credentials.email);
    final profile = await _loadOrCreateProfile(
      credentials: credentials,
      firstName: inferredNames.$1,
      lastName: inferredNames.$2,
      email: credentials.email,
    );

    return _bundleFromProfile(
      credentials: credentials,
      profile: profile,
      emailVerified: verified,
      fallbackFirstName: inferredNames.$1,
      fallbackLastName: inferredNames.$2,
    );
  }

  @override
  Future<Uri> createGoalLockCheckoutSession({
    required RemoteCredentials credentials,
  }) async {
    final response = await _request(
      method: 'POST',
      uri: _functionUri('goalLockCreateCheckoutSession'),
      bearerToken: credentials.idToken,
      payload: const <String, dynamic>{},
    );
    final url = response?['url'] as String?;
    if (url == null || url.trim().isEmpty) {
      throw const BridgeException(
        'No checkout URL came back from billing. Please try again.',
      );
    }
    return Uri.parse(url);
  }

  @override
  Future<Uri> createGoalLockBillingPortalSession({
    required RemoteCredentials credentials,
  }) async {
    final response = await _request(
      method: 'POST',
      uri: _functionUri('goalLockCreateBillingPortalSession'),
      bearerToken: credentials.idToken,
      payload: const <String, dynamic>{},
    );
    final url = response?['url'] as String?;
    if (url == null || url.trim().isEmpty) {
      throw const BridgeException(
        'No billing portal URL came back from billing. Please try again.',
      );
    }
    return Uri.parse(url);
  }

  @override
  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
  }) async {
    final goalId = plan.goalId ?? _randomGoalId();
    final syncedPlan = plan.copyWith(goalId: goalId, armed: true);

    await _patchDocument(
      collection: 'rocketGoals',
      documentId: goalId,
      idToken: credentials.idToken,
      values: <String, dynamic>{
        'id': goalId,
        'userId': account.userId,
        'primaryGoal': syncedPlan.goal,
        'status': 'active',
        'entryPoint': 'launch_challenge',
        'participant': <String, dynamic>{
          'firstName': account.firstName,
          'lastName': account.lastName,
          'email': account.email,
        },
        'createdAt': syncedPlan.createdAt.toUtc(),
        'goalLock': <String, dynamic>{
          'armed': true,
          'morningTimeMinutes': syncedPlan.morningLockMinutes,
          'focusWindowHours': syncedPlan.focusWindowHours,
          'reflectionTimeMinutes': syncedPlan.reflectionLockMinutes,
          'lastUpdatedAt': DateTime.now().toUtc(),
          if (latestCommitment != null)
            'latestOneThing': latestCommitment.oneThing,
          if (latestCommitment != null)
            'latestOneThingDate': latestCommitment.dateKey,
          if (latestCommitment?.didComplete != null)
            'latestReflectionComplete': latestCommitment!.didComplete,
        },
      },
    );

    await _patchDocument(
      collection: 'userProfiles',
      documentId: account.userId,
      idToken: credentials.idToken,
      values: <String, dynamic>{'myOneThingGoalId': goalId},
    );

    return syncedPlan;
  }

  Future<LinkedAccountBundle> _bundleFromProfile({
    required RemoteCredentials credentials,
    required Map<String, dynamic> profile,
    required bool emailVerified,
    required String fallbackFirstName,
    required String fallbackLastName,
  }) async {
    final importedGoal = await _loadLinkedGoal(
      goalId: profile['myOneThingGoalId'] as String?,
      defaultGoalLabel: profile['primaryGoal'] as String?,
    );

    final account = UserAccount(
      userId: credentials.userId,
      firstName: (profile['firstName'] as String?) ?? fallbackFirstName,
      lastName: (profile['lastName'] as String?) ?? fallbackLastName,
      email: credentials.email,
      mode: ExperienceMode.linked,
      emailVerified: emailVerified,
      isAdmin: _isAdminProfile(profile),
      goalLockAccessGranted: profile['goalLockAccessGranted'] as bool? ?? false,
      goalLockSubscriptionStatus:
          profile['goalLockSubscriptionStatus'] as String?,
      goalLockSubscriptionExpiresAt: _asDateTime(
        profile['goalLockSubscriptionExpiresAt'],
      ),
      goalLockSubscriptionCancelAt: _asDateTime(
        profile['goalLockSubscriptionCancelAt'],
      ),
      goalLockIntroOfferUsed:
          profile['goalLockIntroOfferUsed'] as bool? ?? false,
    );

    return LinkedAccountBundle(
      account: account,
      credentials: credentials,
      importedGoal: importedGoal,
      notice: account.hasGoalLockAccess
          ? (importedGoal == null
                ? 'Rocket Goals account linked. Set one goal and arm tomorrow.'
                : 'Rocket Goals account linked. We pulled your existing mission in.')
          : 'Complete payment to unlock Goal Lock.',
    );
  }

  Future<Map<String, dynamic>> _lookupAccount(String idToken) async {
    final response = await _postJson(
      _identityUri('accounts:lookup'),
      <String, dynamic>{'idToken': idToken},
    );
    final users = response['users'] as List<dynamic>? ?? const [];
    if (users.isEmpty) {
      throw const BridgeException('Unable to load your account details.');
    }
    final user = users.first;
    if (user is Map<String, dynamic>) {
      return user;
    }
    return (user as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _loadOrCreateProfile({
    required RemoteCredentials credentials,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final existing = await _getDocument(
      collection: 'userProfiles',
      documentId: credentials.userId,
      idToken: credentials.idToken,
    );

    if (existing != null) {
      return existing;
    }

    final values = <String, dynamic>{
      'id': credentials.userId,
      'userId': credentials.userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'createdAt': DateTime.now().toUtc(),
      'goalLockAccessGranted': false,
      'goalLockIntroOfferUsed': false,
    };

    await _patchDocument(
      collection: 'userProfiles',
      documentId: credentials.userId,
      idToken: credentials.idToken,
      values: values,
    );

    return values;
  }

  Future<GoalPlan?> _loadLinkedGoal({
    required String? goalId,
    required String? defaultGoalLabel,
  }) async {
    if (goalId == null || goalId.isEmpty) {
      if (defaultGoalLabel == null || defaultGoalLabel.trim().isEmpty) {
        return null;
      }
      return GoalPlan(
        goal: defaultGoalLabel.trim(),
        morningLockMinutes: 390,
        focusWindowHours: 14,
        createdAt: DateTime.now(),
        armed: false,
        importedFromRocketGoals: true,
      );
    }

    final document = await _getDocument(
      collection: 'rocketGoals',
      documentId: goalId,
      idToken: null,
    );

    if (document == null) {
      return null;
    }

    final goalLock =
        (document['goalLock'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final morningLock = normalizeMinutesOfDay(
      _asInt(goalLock['morningTimeMinutes']) ?? 390,
    );
    final focusWindow = clampFocusWindowHours(
      _asInt(goalLock['focusWindowHours']) ?? 14,
    );
    final armed = goalLock['armed'] as bool? ?? false;

    return GoalPlan(
      goalId: goalId,
      goal: (document['primaryGoal'] as String?) ?? defaultGoalLabel ?? '',
      morningLockMinutes: morningLock,
      focusWindowHours: focusWindow,
      createdAt: DateTime.now(),
      armed: armed,
      importedFromRocketGoals: true,
    );
  }

  Future<Map<String, dynamic>?> _getDocument({
    required String collection,
    required String documentId,
    required String? idToken,
  }) async {
    final response = await _request(
      method: 'GET',
      uri: _firestoreDocumentUri(collection, documentId),
      bearerToken: idToken,
      allow404: true,
    );

    if (response == null) {
      return null;
    }

    return _decodeDocument(response);
  }

  Future<void> _patchDocument({
    required String collection,
    required String documentId,
    required String idToken,
    required Map<String, dynamic> values,
  }) async {
    await _request(
      method: 'PATCH',
      uri: _firestoreDocumentUri(
        collection,
        documentId,
        updateMaskFieldPaths: values.keys,
      ),
      bearerToken: idToken,
      payload: <String, dynamic>{'fields': _encodeFields(values)},
    );
  }

  Uri _identityUri(String action) {
    if (_apiKey.isEmpty) {
      throw const BridgeException(
        'Missing Rocket Goals Firebase API key. Start the app with '
        '--dart-define=ROCKET_GOALS_FIREBASE_API_KEY=... '
        '(or legacy --dart-define=ROCKET_GOALS_API_KEY=...) '
        'or use Preview mode.',
      );
    }
    return Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/$action',
      <String, dynamic>{'key': _apiKey},
    );
  }

  Uri _firestoreDocumentUri(
    String collection,
    String documentId, {
    Iterable<String> updateMaskFieldPaths = const [],
  }) {
    final baseUri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/(default)/documents/$collection/$documentId',
    );
    if (updateMaskFieldPaths.isEmpty) {
      return baseUri;
    }
    final query = updateMaskFieldPaths
        .map(
          (fieldPath) =>
              'updateMask.fieldPaths=${Uri.encodeQueryComponent(fieldPath)}',
        )
        .join('&');
    return baseUri.replace(query: query);
  }

  Uri _functionUri(String name) {
    if (_functionsOrigin.isNotEmpty) {
      final base = _functionsOrigin.endsWith('/')
          ? _functionsOrigin.substring(0, _functionsOrigin.length - 1)
          : _functionsOrigin;
      return Uri.parse('$base/$name');
    }

    return Uri.https('us-central1-$_projectId.cloudfunctions.net', '/$name');
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    return await _request(method: 'POST', uri: uri, payload: payload) ??
        <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _request({
    required String method,
    required Uri uri,
    Map<String, dynamic>? payload,
    String? bearerToken,
    bool allow404 = false,
  }) async {
    final client = HttpClient();
    try {
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        _ => await client.postUrl(uri),
      };

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $bearerToken',
        );
      }
      if (payload != null) {
        request.write(jsonEncode(payload));
      }

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();

      if (allow404 && response.statusCode == HttpStatus.notFound) {
        return null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BridgeException(_extractErrorMessage(rawBody));
      }

      if (rawBody.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return (decoded as Map).cast<String, dynamic>();
    } on SocketException {
      throw const BridgeException(
        'Network unavailable. Linking needs a live connection, but Preview mode still works.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _extractErrorMessage(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return 'Something went wrong while talking to Rocket Goals.';
    }

    try {
      final decoded = jsonDecode(rawBody);
      final root = decoded is Map<String, dynamic>
          ? decoded
          : (decoded as Map).cast<String, dynamic>();
      final topLevelMessage = root['message'] as String?;
      if (topLevelMessage != null && topLevelMessage.trim().isNotEmpty) {
        return topLevelMessage;
      }
      final topLevelError = root['error'];
      if (topLevelError is String && topLevelError.trim().isNotEmpty) {
        return topLevelError;
      }
      final error = root['error'] is Map<String, dynamic>
          ? root['error'] as Map<String, dynamic>
          : (root['error'] as Map?)?.cast<String, dynamic>();
      final message = error?['message'] as String?;
      if (message == null) {
        return 'Something went wrong while talking to Rocket Goals.';
      }
      return switch (message) {
        'EMAIL_NOT_FOUND' => 'No Rocket Goals account matches that email.',
        'INVALID_PASSWORD' => 'That password is incorrect.',
        'EMAIL_EXISTS' => 'That email already has a Rocket Goals account.',
        'WEAK_PASSWORD : Password should be at least 6 characters' =>
          'Password must be at least 6 characters.',
        'TOO_MANY_ATTEMPTS_TRY_LATER' =>
          'Too many attempts. Try again in a moment.',
        _ => message.replaceAll('_', ' ').toLowerCase(),
      };
    } catch (_) {
      return 'Something went wrong while talking to Rocket Goals.';
    }
  }

  Map<String, dynamic> _decodeDocument(Map<String, dynamic> document) {
    final fields =
        (document['fields'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return fields.map(
      (key, value) => MapEntry(
        key,
        _decodeFirestoreValue(
          value is Map<String, dynamic>
              ? value
              : (value as Map).cast<String, dynamic>(),
        ),
      ),
    );
  }

  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map(
      (key, value) => MapEntry(key, _encodeFirestoreValue(value)),
    );
  }

  Map<String, dynamic> _encodeFirestoreValue(Object? value) {
    if (value == null) {
      return <String, dynamic>{'nullValue': null};
    }
    if (value is String) {
      return <String, dynamic>{'stringValue': value};
    }
    if (value is bool) {
      return <String, dynamic>{'booleanValue': value};
    }
    if (value is int) {
      return <String, dynamic>{'integerValue': value.toString()};
    }
    if (value is double) {
      return <String, dynamic>{'doubleValue': value};
    }
    if (value is DateTime) {
      return <String, dynamic>{
        'timestampValue': value.toUtc().toIso8601String(),
      };
    }
    if (value is List) {
      return <String, dynamic>{
        'arrayValue': <String, dynamic>{
          'values': value.map(_encodeFirestoreValue).toList(),
        },
      };
    }
    if (value is Map) {
      final castMap = value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
      return <String, dynamic>{
        'mapValue': <String, dynamic>{'fields': _encodeFields(castMap)},
      };
    }
    return <String, dynamic>{'stringValue': value.toString()};
  }

  dynamic _decodeFirestoreValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) {
      return value['stringValue'] as String;
    }
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'] as bool;
    }
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'] as String? ?? '') ?? 0;
    }
    if (value.containsKey('doubleValue')) {
      return value['doubleValue'] as double;
    }
    if (value.containsKey('timestampValue')) {
      return DateTime.tryParse(value['timestampValue'] as String? ?? '');
    }
    if (value.containsKey('arrayValue')) {
      final raw =
          (value['arrayValue'] as Map<String, dynamic>?)?['values']
              as List<dynamic>? ??
          const [];
      return raw
          .map(
            (entry) => _decodeFirestoreValue(
              entry is Map<String, dynamic>
                  ? entry
                  : (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    }
    if (value.containsKey('mapValue')) {
      final rawFields =
          (value['mapValue'] as Map<String, dynamic>?)?['fields'] as Map?;
      final cast =
          rawFields?.cast<String, dynamic>() ?? const <String, dynamic>{};
      return cast.map(
        (key, entryValue) => MapEntry(
          key,
          _decodeFirestoreValue(
            entryValue is Map<String, dynamic>
                ? entryValue
                : (entryValue as Map).cast<String, dynamic>(),
          ),
        ),
      );
    }
    return null;
  }

  (String, String) _splitName(String displayName, String email) {
    final trimmed = displayName.trim();
    if (trimmed.isNotEmpty) {
      final pieces = trimmed.split(RegExp(r'\s+'));
      if (pieces.length == 1) {
        return (pieces.first, '');
      }
      return (pieces.first, pieces.sublist(1).join(' '));
    }

    final fallback = email.split('@').first;
    return (fallback, '');
  }

  String _randomGoalId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'goal_lock_$now$rand';
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  DateTime? _asDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _isAdminProfile(Map<String, dynamic> profile) {
    return profile['admin'] == true || profile['role'] == 'admin';
  }
}

RocketGoalsBridge createPlatformBridge() => _FirebaseRestBridge();
