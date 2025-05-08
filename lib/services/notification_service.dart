/*
* File: lib/services/notification_service.dart
* Description: Service for handling local notifications in the Milo App
* Date: May 7, 2025
* Author: Milo App Development Team
*/

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import '../core/exceptions.dart';
import '../config/constants.dart';
import '../services/logging_service.dart';
import 'package:get_it/get_it.dart';

/// Service responsible for managing local notifications.
///
/// This service handles:
/// - Initialization of the notification system
/// - Scheduling medication reminders
/// - Handling notification interactions
/// - Managing notification channels and settings
class NotificationService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification channels
  final String _medicationChannelId = AppConstants.medicationChannelId;
  final String _medicationChannelName = AppConstants.medicationChannelName;
  final String _medicationChannelDescription =
      AppConstants.medicationChannelDescription;

  // Notification IDs
  final int _baseNotificationId =
      10000; // Use a high base ID to avoid conflicts

  /// Initializes the notification service.
  ///
  /// Sets up notification channels and requests permissions.
  /// This must be called before any notifications can be scheduled.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing notification service');

      // Initialize timezone database
      tz.initializeTimeZones();

      // Set local location (default to local device time)
      tz.setLocalLocation(tz.getLocation('UTC'));

      // Initialize notification settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Initialize iOS settings
      final DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            requestCriticalPermission: true,
            notificationCategories: [],
          );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      // Initialize the plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // Create notification channels on Android
      if (Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }

      _isInitialized = true;
      _logger.info('Notification service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize notification service', e, stackTrace);
      throw NotificationException(
        code: 'NOTIFICATION_INIT_FAILED',
        message:
            'Failed to initialize notification service. Please check notification permissions.',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Creates the Android notification channel for medication reminders.
  Future<void> _createAndroidNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) return;

    // Create medication reminders channel
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _medicationChannelId,
        _medicationChannelName,
        description: _medicationChannelDescription,
        importance: Importance.high,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        showBadge: true,
      ),
    );
  }

  /// Handles notification tap on iOS and Android.
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _logger.debug('Notification response received: ${response.payload}');

    // Extract payload data
    if (response.payload != null) {
      // For medication reminders, the payload is the medication ID
      // This will be handled by the app's notification handler
      _logger.debug('Notification payload: ${response.payload}');
    }
  }

  /// Schedules a medication reminder notification.
  ///
  /// [id] Unique identifier for the notification (usually medicationId_datetime)
  /// [title] Title of the notification
  /// [body] Body text of the notification
  /// [scheduledTime] When to show the notification
  /// [medicationId] ID of the medication for the payload
  /// [channelId] Optional: Android notification channel ID (defaults to medication channel)
  /// [channelName] Optional: Android notification channel name
  /// [channelDescription] Optional: Android notification channel description
  Future<void> scheduleMedicationReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String medicationId,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Convert the ID string to a numeric ID using a simple hash
      final int notificationId =
          _baseNotificationId + id.hashCode.abs() % 10000;

      // Convert DateTime to TZDateTime
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Check if the scheduled time is in the past
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      if (tzScheduledTime.isBefore(now)) {
        _logger.warning(
          'Attempted to schedule a notification in the past: $scheduledTime',
        );
        return;
      }

      // Use provided channel values or defaults
      final String notifChannelId = channelId ?? _medicationChannelId;
      final String notifChannelName = channelName ?? _medicationChannelName;
      final String notifChannelDescription =
          channelDescription ?? _medicationChannelDescription;

      // Configure notification details
      final AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        notifChannelId,
        notifChannelName,
        channelDescription: notifChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Medication Reminder',
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        // Added settings to ensure notification persists until user interaction
        autoCancel: false, // Prevent auto-dismissal
        ongoing: true, // Make notification persistent
        category: AndroidNotificationCategory.reminder,
      );

      final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel:
            InterruptionLevel.timeSensitive, // Higher interrupt level
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // Schedule the notification
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: medicationId,
      );

      _logger.info('Scheduled medication reminder: $title for $scheduledTime');
    } catch (e, stackTrace) {
      _logger.error('Failed to schedule medication reminder', e, stackTrace);
      throw NotificationException(
        code: 'NOTIFICATION_SCHEDULE_FAILED',
        message:
            'Failed to schedule reminder. Please check notification permissions.',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Cancels all medication reminders.
  Future<void> cancelAllMedicationReminders() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Cancel all notifications
      await _flutterLocalNotificationsPlugin.cancelAll();
      _logger.info('Cancelled all medication reminders');
    } catch (e, stackTrace) {
      _logger.error('Failed to cancel all medication reminders', e, stackTrace);
      throw NotificationException(
        code: 'NOTIFICATION_CANCEL_FAILED',
        message: 'Failed to cancel medication reminders',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Cancels all reminders for a specific medication.
  ///
  /// [medicationId] ID of the medication to cancel reminders for
  /// Note: Since we can't query notifications by payload, we can't
  /// target specific medication IDs directly. Instead, we'd need to
  /// maintain a mapping of medication IDs to notification IDs.
  /// For MVP, we'll simply cancel all notifications.
  Future<void> cancelMedicationReminders(String medicationId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // For MVP, we'll just cancel all notifications
      // In a future version, we would maintain a mapping of medication IDs to notification IDs
      await _flutterLocalNotificationsPlugin.cancelAll();
      _logger.info('Cancelled reminders for medication: $medicationId');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cancel reminders for medication: $medicationId',
        e,
        stackTrace,
      );
      throw NotificationException(
        code: 'NOTIFICATION_CANCEL_FAILED',
        message: 'Failed to cancel medication reminders',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Checks if notifications are enabled.
  ///
  /// Returns true if notifications are enabled, false otherwise.
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosPlugin =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        if (iosPlugin != null) {
          final bool? result = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return result ?? false;
        }
        return false;
      } else if (Platform.isAndroid) {
        // Use permission_handler to check notification permission status
        final status = await Permission.notification.status;
        return status.isGranted;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check if notifications are enabled',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Requests notification permissions if they haven't been granted.
  ///
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestNotificationPermissions() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosPlugin =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        if (iosPlugin != null) {
          final bool? result = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return result ?? false;
        }
        return false;
      } else if (Platform.isAndroid) {
        // For Android 13+, use permission_handler
        final status = await Permission.notification.request();
        return status.isGranted;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to request notification permissions',
        e,
        stackTrace,
      );
      return false;
    }
  }
}

/// Custom exception for notification errors
class NotificationException extends MiloException {
  /// Creates a new NotificationException
  const NotificationException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when notification permission is denied
  factory NotificationException.permissionDenied({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return NotificationException(
      code: 'NOTIFICATION_PERMISSION_DENIED',
      message: 'Notification permission is needed for medication reminders',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when scheduling a notification fails
  factory NotificationException.scheduleFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return NotificationException(
      code: 'NOTIFICATION_SCHEDULE_FAILED',
      message: 'Failed to schedule reminder',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}
