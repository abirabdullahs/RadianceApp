import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../constants.dart';
import '../supabase_client.dart';

/// Top-level handler required for background FCM (must not be a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background: ${message.messageId}');
}

/// Initializes Firebase Messaging, local notifications, persists FCM token to [kTableUsers].
class FcmService {
  FcmService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'radiance_default',
    'Radiance',
    description: 'General notifications',
    importance: Importance.defaultImportance,
  );

  /// Call after [initSupabase]. Safe to call when Firebase is not configured (no-ops).
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      debugPrint('Firebase init skipped: $e');
      return;
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied');
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _persistToken(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final n = message.notification;
        if (n != null) {
          await _local.show(
            message.hashCode,
            n.title ?? kAppName,
            n.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            payload: message.data['action_route'] as String?,
          );
        }
      });
    } catch (e, st) {
      // Placeholder firebase_options / missing google-services.json → invalid API key, etc.
      debugPrint(
        'FCM not active (run `flutterfire configure` and add real google-services.json): $e',
      );
      debugPrint('$st');
    }
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final route = response.payload;
    if (route != null && route.isNotEmpty) {
      // Deep link: router can listen via a stream or global key — keep payload for future.
      debugPrint('Notification tap payload: $route');
    }
  }

  static Future<void> _persistToken(String token) async {
    final uid = supabaseClient.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabaseClient.from(kTableUsers).update(<String, dynamic>{
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e, st) {
      debugPrint('Failed to save FCM token: $e\n$st');
    }
  }

  /// Re-save token after login (session may have been null during cold start).
  static Future<void> syncTokenAfterAuth() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _persistToken(token);
    } catch (_) {}
  }
}
