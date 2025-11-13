import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/dhikr.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Add navigation logic here (navigate to the specific dhikr detail page)
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      // Request permissions for iOS
      final bool? iosGranted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Request permissions for Android 13+
      final bool? androidGranted =
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();

      debugPrint(
        'Notification permissions - iOS: $iosGranted, Android: $androidGranted',
      );

      return iosGranted ?? androidGranted ?? true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      // Check Android
      final bool? androidEnabled =
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled();

      if (androidEnabled != null) {
        return androidEnabled;
      }

      // For iOS, we assume enabled if permissions were granted
      // (iOS doesn't provide a direct check method)
      return true;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }

  /// Schedule a notification for a specific dhikr
  Future<void> scheduleDhikrNotification(Dhikr dhikr) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Call init() first.');
      return;
    }

    // Check if dhikr has a scheduled time
    if (dhikr.when == null || dhikr.id == null) {
      debugPrint('Dhikr has no scheduled time or ID. Skipping notification.');
      return;
    }

    // Check if the scheduled time is in the future
    if (dhikr.when!.isBefore(DateTime.now())) {
      debugPrint('Dhikr scheduled time is in the past. Skipping notification.');
      return;
    }

    try {
      // Convert DateTime to TZDateTime
      final scheduledDate = tz.TZDateTime.from(dhikr.when!, tz.local);

      // Create notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'dhikr_reminders', // Channel ID
            'Dhikr Reminders', // Channel name
            channelDescription: 'Notifications for scheduled dhikr reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create notification title and body
      final title = 'Time for Dhikr';
      final body = 'Time to recite ${dhikr.dhikrTitle} ${dhikr.times} times';

      // Schedule the notification
      await _notificationsPlugin.zonedSchedule(
        dhikr.id!, // Use dhikr ID as notification ID
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: dhikr.id.toString(), // Pass dhikr ID as payload
      );

      debugPrint(
        'Scheduled notification for "${dhikr.dhikrTitle}" at ${dhikr.when}',
      );
    } catch (e) {
      debugPrint('Error scheduling notification for dhikr ${dhikr.id}: $e');
    }
  }

  /// Cancel a notification for a specific dhikr
  Future<void> cancelDhikrNotification(int dhikrId) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Call init() first.');
      return;
    }

    try {
      await _notificationsPlugin.cancel(dhikrId);
      debugPrint('Cancelled notification for dhikr ID: $dhikrId');
    } catch (e) {
      debugPrint('Error cancelling notification for dhikr $dhikrId: $e');
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Call init() first.');
      return;
    }

    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('Cancelled all notifications');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Call init() first.');
      return [];
    }

    try {
      final pendingNotifications =
          await _notificationsPlugin.pendingNotificationRequests();
      debugPrint('Pending notifications: ${pendingNotifications.length}');
      return pendingNotifications;
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Show an immediate notification
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Call init() first.');
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'dhikr_reminders',
            'Dhikr Reminders',
            channelDescription: 'Notifications for scheduled dhikr reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(id, title, body, notificationDetails);

      debugPrint('Showed immediate notification: $title');
    } catch (e) {
      debugPrint('Error showing immediate notification: $e');
    }
  }

  /// Reschedule notification (cancel old and schedule new)
  Future<void> rescheduleDhikrNotification(Dhikr dhikr) async {
    if (dhikr.id == null) return;

    // Cancel existing notification
    await cancelDhikrNotification(dhikr.id!);

    // Schedule new notification
    await scheduleDhikrNotification(dhikr);
  }

  /// Schedule notifications for multiple dhikrs
  Future<void> scheduleMultipleDhikrNotifications(List<Dhikr> dhikrs) async {
    for (final dhikr in dhikrs) {
      await scheduleDhikrNotification(dhikr);
    }
    debugPrint('Scheduled ${dhikrs.length} dhikr notifications');
  }

  /// Check if a specific notification is pending
  Future<bool> isNotificationPending(int dhikrId) async {
    final pendingNotifications = await getPendingNotifications();
    return pendingNotifications.any(
      (notification) => notification.id == dhikrId,
    );
  }

  /// Get notification details for debugging
  Future<Map<String, dynamic>> getNotificationDebugInfo() async {
    try {
      final pendingNotifications = await getPendingNotifications();
      final isEnabled = await areNotificationsEnabled();

      return {
        'isInitialized': _isInitialized,
        'notificationsEnabled': isEnabled,
        'pendingCount': pendingNotifications.length,
        'pendingNotifications':
            pendingNotifications
                .map(
                  (n) => {
                    'id': n.id,
                    'title': n.title,
                    'body': n.body,
                    'payload': n.payload,
                  },
                )
                .toList(),
      };
    } catch (e) {
      return {'error': e.toString(), 'isInitialized': _isInitialized};
    }
  }
}
