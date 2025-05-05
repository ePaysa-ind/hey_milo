/*
* File: lib/config/constants.dart
* Description: Application-wide constants
* Date: May 5, 2025
* Author: Milo App Development Team
*/


/// Application-wide constants.
///
/// This class contains constants used throughout the app.
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App information
  static const String appName = 'Milo';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String appPackageName = 'com.miloapp.memories';

  // File paths and extensions
  static const String recordingFileExtension = '.m4a';
  static const String defaultMemoriesDirectoryName = 'memories';
  static const String defaultCaregiverMessagesDirectoryName = 'caregiver_messages';

  // Accessibility constants
  static const double minTouchTargetSize = 48.0;
  static const double borderRadius = 12.0;
  static const double defaultPadding = 16.0;

  // Recording constants
  static const int maxRecordingDurationSeconds = 300; // 5 minutes
  static const int maxCaregiverMessageSizeMb = 10;
  // Permission constants
  static const Duration permissionRequestTimeout = Duration(seconds: 10); // Timeout for permission requests

  // Notification constants
  static const String medicationChannelId = 'medication_reminders';
  static const String medicationChannelName = 'Medication Reminders';
  static const String medicationChannelDescription = 'Notifications for medication reminders';

  // Storage constants
  static const int freeUsageLimit = 100; // Number of recordings before paywall (R1)

  // SharedPreferences keys
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyIsOnboarded = 'is_onboarded';
  static const String keyIsAudioPlayerExpanded = 'is_audio_player_expanded';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTextSize = 'text_size';
  static const String keyUseHighContrast = 'use_high_contrast';
  static const String keyEnableNotifications = 'enable_notifications';
  static const String keyAutoDeleteDays = 'auto_delete_days';
  static const String keyLastDataCleanupDate = 'last_data_cleanup_date';

  // Error retry constants
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // File paths
  static const String pathCaregiverMessages = 'caregiver_messages.json';

  // Cleanup constants
  static const int cleanupIntervalDays = 7; // Run cleanup once per week
  static const int logRetentionDays = 30; // Keep logs for 30 days
  static const int tempFileRetentionHours = 24; // Keep temp files for 24 hours
  static const int defaultAutoDeleteDays = 30; // Default retention period for recordings
}