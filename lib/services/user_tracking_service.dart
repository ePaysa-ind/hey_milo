/*
* File: lib/services/usage_tracking_service.dart
* Description: Service for tracking app usage statistics locally
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:get_it/get_it.dart';

import '../core/exceptions.dart';
import '../services/logging_service.dart';
import '../services/local_storage_service.dart';

/// Type of event to track in the application
enum UsageEventType {
  /// App lifecycle events
  appOpen,
  appClose,
  appCrash,

  /// Feature usage events
  recordingCreated,
  recordingPlayed,
  recordingDeleted,

  /// Medication events
  medicationAdded,
  medicationReminder,
  medicationTaken,

  /// Caregiver events
  caregiverMessageSent,
  caregiverMessageReceived,

  /// Screen navigation events
  screenView,

  /// Settings changes
  settingsChanged,

  /// Error events
  error,

  /// Other custom events
  custom
}

/// Service responsible for tracking app usage locally.
///
/// This service handles:
/// - Tracking app usage events
/// - Recording feature usage statistics
/// - Storing usage data locally
/// - Providing usage insights
///
/// All data is stored locally and never sent to any servers.
class UsageTrackingService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final LocalStorageService _localStorageService;

  bool _isInitialized = false;
  bool _isEnabled = true;

  late final String _usageDataPath;
  static const String _usageFileName = 'usage_statistics.json';
  static const String _usageEventsFileName = 'usage_events.json';

  // In-memory cache of usage statistics
  Map<String, dynamic> _usageStats = {};
  List<Map<String, dynamic>> _recentEvents = [];

  // Maximum number of events to keep in history
  static const int _maxEventHistory = 1000;

  /// Creates a new UsageTrackingService instance.
  UsageTrackingService({
    required LocalStorageService localStorageService,
  }) : _localStorageService = localStorageService;

  /// Initializes the usage tracking service.
  ///
  /// This must be called before any tracking can be performed.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('UsageTrackingService: Initializing usage tracking service');

      await _localStorageService.initialize();

      // Define the path for usage statistics
      final appDocDir = await _localStorageService.getAppDocumentsDirectory();
      final usageDir = Directory(path.join(appDocDir.path, 'usage_data'));

      // Create the directory if it doesn't exist
      if (!await usageDir.exists()) {
        await usageDir.create(recursive: true);
      }

      _usageDataPath = usageDir.path;

      // Load existing usage statistics
      await _loadUsageStatistics();

      // Set initial usage stats if not exists
      if (_usageStats.isEmpty) {
        _usageStats = {
          'firstUseDate': DateTime.now().millisecondsSinceEpoch,
          'lastUseDate': DateTime.now().millisecondsSinceEpoch,
          'appOpenCount': 0,
          'totalUsageTimeMinutes': 0,
          'recordingsCreated': 0,
          'recordingsPlayed': 0,
          'recordingsDeleted': 0,
          'medicationsAdded': 0,
          'medicationRemindersSent': 0,
          'medicationTaken': 0,
          'caregiverMessagesSent': 0,
          'caregiverMessagesReceived': 0,
          'errorCount': 0,
          'screenViews': <String, int>{},
          'featureUsage': <String, int>{},
        };

        await _saveUsageStatistics();
      }

      _isInitialized = true;
      _logger.info('UsageTrackingService: Successfully initialized');
    } catch (e, stackTrace) {
      _logger.error('UsageTrackingService: Failed to initialize usage tracking service', e, stackTrace);
      throw StorageException(
        code: 'USAGE_TRACKING_INIT_FAILED',
        message: 'Failed to initialize usage tracking service',
      );
    }
  }

  /// Tracks an app usage event.
  ///
  /// [eventType] The type of event to track.
  /// [details] Optional additional details about the event.
  /// [screenName] Optional screen name if tracking a screen view.
  /// [duration] Optional duration in milliseconds for timed events.
  Future<void> trackEvent(
      UsageEventType eventType, {
        Map<String, dynamic>? details,
        String? screenName,
        int? duration,
      }) async {
    if (!_isInitialized) await initialize();
    if (!_isEnabled) return;

    try {
      final eventTime = DateTime.now();

      // Create the event object
      final event = <String, dynamic>{
        'type': eventType.toString().split('.').last,
        'timestamp': eventTime.millisecondsSinceEpoch,
        'date': eventTime.toIso8601String(),
      };

      // Add optional parameters if provided
      if (details != null) {
        event['details'] = details;
      }

      if (screenName != null) {
        event['screenName'] = screenName;
      }

      if (duration != null) {
        event['durationMs'] = duration;
      }

      // Update in-memory usage statistics
      _updateStatistics(eventType, screenName: screenName, details: details, duration: duration);

      // Add to recent events list
      _recentEvents.add(event);

      // Trim the list if it exceeds the maximum size
      if (_recentEvents.length > _maxEventHistory) {
        _recentEvents.removeRange(0, _recentEvents.length - _maxEventHistory);
      }

      // Save to disk occasionally
      // To reduce I/O, we don't save every single event
      if (_shouldSaveEvent(eventType) || _recentEvents.length % 10 == 0) {
        await _saveUsageStatistics();
        await _saveRecentEvents();
      }

      _logger.debug('UsageTrackingService: Tracked event $eventType');
    } catch (e, stackTrace) {
      // Don't throw exceptions for tracking issues - just log them
      _logger.error('UsageTrackingService: Failed to track event', e, stackTrace);
    }
  }

  /// Tracks app open event and starts session timing.
  Future<void> trackAppOpen() async {
    await trackEvent(UsageEventType.appOpen);

    // Update app open count and last use date
    _usageStats['appOpenCount'] = (_usageStats['appOpenCount'] ?? 0) + 1;
    _usageStats['lastUseDate'] = DateTime.now().millisecondsSinceEpoch;

    await _saveUsageStatistics();
  }

  /// Tracks app close event and updates session timing.
  ///
  /// [sessionDurationMinutes] The duration of the session in minutes.
  Future<void> trackAppClose(double sessionDurationMinutes) async {
    await trackEvent(
      UsageEventType.appClose,
      duration: (sessionDurationMinutes * 60 * 1000).round(), // Convert to milliseconds
    );

    // Update total usage time
    _usageStats['totalUsageTimeMinutes'] =
        (_usageStats['totalUsageTimeMinutes'] ?? 0) + sessionDurationMinutes;

    await _saveUsageStatistics();
  }

  /// Tracks a screen view.
  ///
  /// [screenName] The name of the screen being viewed.
  Future<void> trackScreenView(String screenName) async {
    await trackEvent(UsageEventType.screenView, screenName: screenName);
  }

  /// Tracks an error event.
  ///
  /// [errorType] The type of error.
  /// [errorMessage] The error message.
  /// [stackTrace] Optional stack trace.
  Future<void> trackError(String errorType, String errorMessage, [StackTrace? stackTrace]) async {
    await trackEvent(
      UsageEventType.error,
      details: {
        'errorType': errorType,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace?.toString(),
      },
    );
  }

  /// Gets usage statistics.
  ///
  /// Returns a map containing usage statistics.
  Future<Map<String, dynamic>> getUsageStatistics() async {
    if (!_isInitialized) await initialize();

    // Return a copy of the statistics to prevent modification
    return Map<String, dynamic>.from(_usageStats);
  }

  /// Gets recent usage events.
  ///
  /// [limit] Maximum number of events to return.
  /// Returns a list of recent usage events.
  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 100}) async {
    if (!_isInitialized) await initialize();

    // Return the most recent events up to the limit
    final startIndex = _recentEvents.length > limit ? _recentEvents.length - limit : 0;
    return _recentEvents.sublist(startIndex).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Enables or disables usage tracking.
  ///
  /// [enabled] Whether tracking should be enabled.
  void setTrackingEnabled(bool enabled) {
    _isEnabled = enabled;
    _logger.info('UsageTrackingService: Usage tracking ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Resets all usage statistics.
  ///
  /// This will delete all collected data and start fresh.
  Future<void> resetUsageStatistics() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('UsageTrackingService: Resetting usage statistics');

      // Reset in-memory data
      _usageStats = {
        'firstUseDate': DateTime.now().millisecondsSinceEpoch,
        'lastUseDate': DateTime.now().millisecondsSinceEpoch,
        'appOpenCount': 0,
        'totalUsageTimeMinutes': 0,
        'recordingsCreated': 0,
        'recordingsPlayed': 0,
        'recordingsDeleted': 0,
        'medicationsAdded': 0,
        'medicationRemindersSent': 0,
        'medicationTaken': 0,
        'caregiverMessagesSent': 0,
        'caregiverMessagesReceived': 0,
        'errorCount': 0,
        'screenViews': <String, int>{},
        'featureUsage': <String, int>{},
      };

      _recentEvents = [];

      // Save empty data to files
      await _saveUsageStatistics();
      await _saveRecentEvents();

      _logger.info('UsageTrackingService: Usage statistics reset successfully');
    } catch (e, stackTrace) {
      _logger.error('UsageTrackingService: Failed to reset usage statistics', e, stackTrace);
      throw StorageException(
        code: 'RESET_USAGE_STATS_FAILED',
        message: 'Failed to reset usage statistics',
      );
    }
  }

  /// Updates in-memory statistics based on the event type.
  void _updateStatistics(
      UsageEventType eventType, {
        String? screenName,
        Map<String, dynamic>? details,
        int? duration,
      }) {
    switch (eventType) {
      case UsageEventType.recordingCreated:
        _usageStats['recordingsCreated'] = (_usageStats['recordingsCreated'] ?? 0) + 1;
        break;

      case UsageEventType.recordingPlayed:
        _usageStats['recordingsPlayed'] = (_usageStats['recordingsPlayed'] ?? 0) + 1;
        break;

      case UsageEventType.recordingDeleted:
        _usageStats['recordingsDeleted'] = (_usageStats['recordingsDeleted'] ?? 0) + 1;
        break;

      case UsageEventType.medicationAdded:
        _usageStats['medicationsAdded'] = (_usageStats['medicationsAdded'] ?? 0) + 1;
        break;

      case UsageEventType.medicationReminder:
        _usageStats['medicationRemindersSent'] = (_usageStats['medicationRemindersSent'] ?? 0) + 1;
        break;

      case UsageEventType.medicationTaken:
        _usageStats['medicationTaken'] = (_usageStats['medicationTaken'] ?? 0) + 1;
        break;

      case UsageEventType.caregiverMessageSent:
        _usageStats['caregiverMessagesSent'] = (_usageStats['caregiverMessagesSent'] ?? 0) + 1;
        break;

      case UsageEventType.caregiverMessageReceived:
        _usageStats['caregiverMessagesReceived'] = (_usageStats['caregiverMessagesReceived'] ?? 0) + 1;
        break;

      case UsageEventType.error:
        _usageStats['errorCount'] = (_usageStats['errorCount'] ?? 0) + 1;
        break;

      case UsageEventType.screenView:
        if (screenName != null) {
          // Ensure the screenViews map exists
          if (!_usageStats.containsKey('screenViews')) {
            _usageStats['screenViews'] = <String, int>{};
          }

          // Ensure the inner map can be used as a map
          if (_usageStats['screenViews'] is! Map) {
            _usageStats['screenViews'] = <String, int>{};
          }

          // Update screen view count
          final screenViews = _usageStats['screenViews'] as Map;
          screenViews[screenName] = (screenViews[screenName] ?? 0) + 1;
        }
        break;

      case UsageEventType.custom:
        if (details != null && details.containsKey('featureName')) {
          final featureName = details['featureName'] as String;

          // Ensure the featureUsage map exists
          if (!_usageStats.containsKey('featureUsage')) {
            _usageStats['featureUsage'] = <String, int>{};
          }

          // Ensure the inner map can be used as a map
          if (_usageStats['featureUsage'] is! Map) {
            _usageStats['featureUsage'] = <String, int>{};
          }

          // Update feature usage count
          final featureUsage = _usageStats['featureUsage'] as Map;
          featureUsage[featureName] = (featureUsage[featureName] ?? 0) + 1;
        }
        break;

      default:
      // Other event types don't update statistics directly
        break;
    }
  }

  /// Determines if an event should trigger an immediate save.
  bool _shouldSaveEvent(UsageEventType eventType) {
    // Save immediately for important events
    return eventType == UsageEventType.appOpen ||
        eventType == UsageEventType.appClose ||
        eventType == UsageEventType.appCrash ||
        eventType == UsageEventType.error;
  }

  /// Loads usage statistics from storage.
  Future<void> _loadUsageStatistics() async {
    try {
      final statsFile = File(path.join(_usageDataPath, _usageFileName));

      if (await statsFile.exists()) {
        final content = await statsFile.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _usageStats = decoded;

        _logger.info('UsageTrackingService: Loaded usage statistics');
      } else {
        _logger.info('UsageTrackingService: No existing usage statistics found');
        _usageStats = {};
      }

      // Load recent events
      final eventsFile = File(path.join(_usageDataPath, _usageEventsFileName));

      if (await eventsFile.exists()) {
        final content = await eventsFile.readAsString();
        final decoded = jsonDecode(content) as List<dynamic>;
        _recentEvents = decoded.cast<Map<String, dynamic>>();

        _logger.info('UsageTrackingService: Loaded ${_recentEvents.length} recent events');
      } else {
        _logger.info('UsageTrackingService: No existing events found');
        _recentEvents = [];
      }
    } catch (e, stackTrace) {
      _logger.error('UsageTrackingService: Failed to load usage statistics', e, stackTrace);
      // Reset to empty if loading fails
      _usageStats = {};
      _recentEvents = [];
    }
  }

  /// Saves usage statistics to storage.
  Future<void> _saveUsageStatistics() async {
    try {
      final statsFile = File(path.join(_usageDataPath, _usageFileName));
      await statsFile.writeAsString(jsonEncode(_usageStats));

      _logger.debug('UsageTrackingService: Saved usage statistics');
    } catch (e, stackTrace) {
      _logger.error('UsageTrackingService: Failed to save usage statistics', e, stackTrace);
    }
  }

  /// Saves recent events to storage.
  Future<void> _saveRecentEvents() async {
    try {
      final eventsFile = File(path.join(_usageDataPath, _usageEventsFileName));
      await eventsFile.writeAsString(jsonEncode(_recentEvents));

      _logger.debug('UsageTrackingService: Saved recent events');
    } catch (e, stackTrace) {
      _logger.error('UsageTrackingService: Failed to save recent events', e, stackTrace);
    }
  }
}