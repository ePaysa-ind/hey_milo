/*
* File: lib/providers/app_state_provider.dart
* Description: Provider for managing global app state and user preferences
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:hey_milo/config/constants.dart';
import '../core/exceptions.dart';
import '../services/local_storage_service.dart';
import '../services/logging_service.dart';
import '../theme/app_theme.dart';

/// Available text size levels for accessibility.
enum TextSizeLevel {
  /// Small text size (0.8x normal)
  small,

  /// Default text size (1.0x)
  normal,

  /// Large text size (1.25x normal)
  large,

  /// Extra large text size (1.5x normal)
  extraLarge,
}

/// Available cloud storage providers for syncing.
enum CloudStorageProvider {
  /// Apple iCloud
  iCloud,

  /// Google Drive
  googleDrive,

  /// Microsoft OneDrive
  oneDrive,
}

/// Manages global app state and preferences.
///
/// This provider handles:
/// - App theme preferences (light/dark)
/// - Text size preferences
/// - First-time user experience state
/// - Onboarding state
/// - Privacy and data sharing preferences
/// - Global app settings
class AppStateProvider with ChangeNotifier {
  final LocalStorageService _localStorageService;
  final LoggingService _loggingService;

  // Theme state
  ThemeMode _themeMode = ThemeMode.system;
  TextSizeLevel _textSizeLevel = TextSizeLevel.normal;

  // Onboarding state
  bool _hasCompletedOnboarding = false;

  // Privacy preferences
  bool _hasAcceptedPrivacyPolicy = false;
  bool _isCloudSyncEnabled = false;
  CloudStorageProvider? _selectedCloudProvider;

  // Accessibility preferences
  bool _isHighContrastEnabled = false;
  bool _isVoicePromptEnabled = true;

  // Usage statistics
  DateTime? _lastOpenedDate;
  int _appOpenCount = 0;

  // Cleanup preferences
  int _autoDeleteDays = AppConstants.defaultAutoDeleteDays;
  int _lastDataCleanupDate = 0; // Timestamp in milliseconds

  // Error state
  String? _errorMessage;

  // Loading state
  bool _isLoading = false;

  // File to store app state
  late final String _appStateFilePath;
  final String _appStateFileName = 'app_state.json';
  final String _appSettingsDirName = 'app_settings';

  /// Constructs an AppStateProvider with required services.
  AppStateProvider({
    required LocalStorageService localStorageService,
    required LoggingService loggingService,
  }) : _localStorageService = localStorageService,
       _loggingService = loggingService {
    // Load app state when provider is initialized
    loadAppState();
  }

  /// Current theme mode (light, dark, or system).
  ThemeMode get themeMode => _themeMode;

  /// Current text size level.
  TextSizeLevel get textSizeLevel => _textSizeLevel;

  /// Whether the user has completed onboarding.
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  /// Whether the user has accepted the privacy policy.
  bool get hasAcceptedPrivacyPolicy => _hasAcceptedPrivacyPolicy;

  /// Whether cloud sync is enabled.
  bool get isCloudSyncEnabled => _isCloudSyncEnabled;

  /// Selected cloud storage provider, if any.
  CloudStorageProvider? get selectedCloudProvider => _selectedCloudProvider;

  /// Whether high contrast mode is enabled.
  bool get isHighContrastEnabled => _isHighContrastEnabled;

  /// Whether voice prompt is enabled.
  bool get isVoicePromptEnabled => _isVoicePromptEnabled;

  /// Last date the app was opened.
  DateTime? get lastOpenedDate => _lastOpenedDate;

  /// Number of times the app has been opened.
  int get appOpenCount => _appOpenCount;

  /// Number of days to keep recordings before auto-deletion.
  int get autoDeleteDays => _autoDeleteDays;

  /// Timestamp of the last data cleanup operation.
  int get lastDataCleanupDate => _lastDataCleanupDate;

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  /// Whether app state is currently being loaded.
  bool get isLoading => _isLoading;

  /// Returns the appropriate ThemeData based on current settings.
  ThemeData getTheme(BuildContext context) {
    // Always use dark theme as base, since app is designed with dark mode in mind
    final baseTheme = AppTheme.darkTheme;

    // Apply text size scaling
    final scaledTextTheme = _getScaledTextTheme(baseTheme.textTheme);

    // Apply high contrast if enabled
    if (_isHighContrastEnabled) {
      return baseTheme.copyWith(
        textTheme: scaledTextTheme,
        // Increase contrast for high contrast mode
        colorScheme: baseTheme.colorScheme.copyWith(
          // Increase contrast by using more vibrant colors
          primary: Colors.white,
          onSurface: Colors.white,
          // Increase text contrast
          surface: Colors.black,
        ),
        // Apply accessible touch target sizes from constants
        buttonTheme: ButtonThemeData(
          minWidth: AppConstants.minTouchTargetSize,
          height: AppConstants.minTouchTargetSize,
          buttonColor: baseTheme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
        ),
      );
    }

    // Return the theme with text size adjustments
    return baseTheme.copyWith(
      textTheme: scaledTextTheme,
      buttonTheme: ButtonThemeData(
        minWidth: AppConstants.minTouchTargetSize,
        height: AppConstants.minTouchTargetSize,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }

  /// Returns a scaled text theme based on the current text size level.
  TextTheme _getScaledTextTheme(TextTheme baseTextTheme) {
    // Get the scaling factor based on the selected text size level
    final double scaleFactor = _getTextScaleFactor();

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: baseTextTheme.displayLarge!.fontSize! * scaleFactor,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: baseTextTheme.displayMedium!.fontSize! * scaleFactor,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: baseTextTheme.bodyLarge!.fontSize! * scaleFactor,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: baseTextTheme.bodyMedium!.fontSize! * scaleFactor,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: baseTextTheme.titleLarge!.fontSize! * scaleFactor,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: baseTextTheme.titleMedium!.fontSize! * scaleFactor,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: baseTextTheme.labelLarge!.fontSize! * scaleFactor,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: baseTextTheme.bodySmall!.fontSize! * scaleFactor,
      ),
    );
  }

  /// Returns the text scale factor based on the current text size level.
  double _getTextScaleFactor() {
    switch (_textSizeLevel) {
      case TextSizeLevel.small:
        return 0.8;
      case TextSizeLevel.normal:
        return 1.0;
      case TextSizeLevel.large:
        return 1.25;
      case TextSizeLevel.extraLarge:
        return 1.5;
    }
  }

  /// Sets the theme mode.
  ///
  /// Note: While the app provides a ThemeMode selector, the actual visual
  /// theme is always dark-based, optimized for elderly users.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> setThemeMode(ThemeMode themeMode) async {
    try {
      _errorMessage = null;

      // Update theme mode
      _themeMode = themeMode;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set theme mode', e, stackTrace);
      return false;
    }
  }

  /// Sets the text size level.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> setTextSizeLevel(TextSizeLevel textSizeLevel) async {
    try {
      _errorMessage = null;

      // Update text size level
      _textSizeLevel = textSizeLevel;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set text size level', e, stackTrace);
      return false;
    }
  }

  /// Marks onboarding as completed.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> completeOnboarding() async {
    try {
      _errorMessage = null;

      // Mark onboarding as completed
      _hasCompletedOnboarding = true;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to complete onboarding', e, stackTrace);
      return false;
    }
  }

  /// Accepts the privacy policy.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> acceptPrivacyPolicy() async {
    try {
      _errorMessage = null;

      // Mark privacy policy as accepted
      _hasAcceptedPrivacyPolicy = true;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to accept privacy policy', e, stackTrace);
      return false;
    }
  }

  /// Enables or disables cloud sync.
  ///
  /// [provider] Cloud storage provider to use, if enabling.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> setCloudSync(
    bool enabled, {
    CloudStorageProvider? provider,
  }) async {
    try {
      _errorMessage = null;

      // Validate provider if enabling
      if (enabled && provider == null && _selectedCloudProvider == null) {
        throw StorageException(
          code: 'PROVIDER_REQUIRED',
          message: 'Please select a cloud storage provider to enable sync.',
        );
      }

      // Update cloud sync state
      _isCloudSyncEnabled = enabled;
      if (provider != null) {
        _selectedCloudProvider = provider;
      }

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set cloud sync', e, stackTrace);
      return false;
    }
  }

  /// Enables or disables high contrast mode.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> setHighContrast(bool enabled) async {
    try {
      _errorMessage = null;

      // Update high contrast state
      _isHighContrastEnabled = enabled;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set high contrast mode', e, stackTrace);
      return false;
    }
  }

  /// Enables or disables voice prompt.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> setVoicePrompt(bool enabled) async {
    try {
      _errorMessage = null;

      // Update voice prompt state
      _isVoicePromptEnabled = enabled;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set voice prompt', e, stackTrace);
      return false;
    }
  }

  /// Records app usage.
  ///
  /// This should be called when the app is opened.
  Future<void> recordAppUsage() async {
    try {
      // Update app open count
      _appOpenCount++;

      // Update last opened date
      _lastOpenedDate = DateTime.now();

      // Save to storage
      await _saveAppState();

      // No need to notify listeners as this doesn't affect UI
    } catch (e, stackTrace) {
      _loggingService.error('Failed to record app usage', e, stackTrace);
    }
  }

  /// Sets the auto-delete days for recordings.
  ///
  /// [days] Number of days to keep recordings before deletion.
  /// Returns true if successful, false otherwise.
  Future<bool> setAutoDeleteDays(int days) async {
    try {
      _errorMessage = null;

      // Validate input
      if (days < 0) {
        throw StateError('Auto-delete days must be a non-negative number');
      }

      // Update auto-delete days
      _autoDeleteDays = days;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set auto-delete days', e, stackTrace);
      return false;
    }
  }

  /// Updates the timestamp of the last data cleanup operation.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> updateLastDataCleanupDate() async {
    try {
      _errorMessage = null;

      // Update last cleanup date timestamp to current time
      _lastDataCleanupDate = DateTime.now().millisecondsSinceEpoch;

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to update last data cleanup date', e, stackTrace);
      return false;
    }
  }

  /// Resets the app state to default.
  ///
  /// This is typically used for troubleshooting or when a user wants to
  /// start fresh without uninstalling the app.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> resetAppState({bool keepUsageStats = true}) async {
    try {
      _errorMessage = null;

      // Store usage stats if we're keeping them
      final appOpenCount = _appOpenCount;
      final lastOpenedDate = _lastOpenedDate;

      // Reset to defaults
      _themeMode = ThemeMode.system;
      _textSizeLevel = TextSizeLevel.normal;
      _hasCompletedOnboarding = false;
      _hasAcceptedPrivacyPolicy = false;
      _isCloudSyncEnabled = false;
      _selectedCloudProvider = null;
      _isHighContrastEnabled = false;
      _isVoicePromptEnabled = true;
      _autoDeleteDays = AppConstants.defaultAutoDeleteDays;
      _lastDataCleanupDate = 0;

      // Restore usage stats if requested
      if (keepUsageStats) {
        _appOpenCount = appOpenCount;
        _lastOpenedDate = lastOpenedDate;
      } else {
        _appOpenCount = 0;
        _lastOpenedDate = null;
      }

      // Save to storage
      await _saveAppState();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to reset app state', e, stackTrace);
      return false;
    }
  }

  /// Loads the app state from storage.
  Future<void> loadAppState() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initializeAppStateFile();

      final File file = File(_appStateFilePath);

      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final Map<String, dynamic> appStateJson = jsonDecode(jsonString);

        if (appStateJson.isNotEmpty) {
          // Theme state
          _themeMode = _parseThemeMode(appStateJson['themeMode']);
          _textSizeLevel = _parseTextSizeLevel(appStateJson['textSizeLevel']);

          // Onboarding state
          _hasCompletedOnboarding =
              appStateJson['hasCompletedOnboarding'] ?? false;

          // Privacy preferences
          _hasAcceptedPrivacyPolicy =
              appStateJson['hasAcceptedPrivacyPolicy'] ?? false;
          _isCloudSyncEnabled = appStateJson['isCloudSyncEnabled'] ?? false;
          _selectedCloudProvider = _parseCloudProvider(
            appStateJson['selectedCloudProvider'],
          );

          // Accessibility preferences
          _isHighContrastEnabled =
              appStateJson['isHighContrastEnabled'] ?? false;
          _isVoicePromptEnabled = appStateJson['isVoicePromptEnabled'] ?? true;

          // Usage statistics
          final lastOpenedDateStr = appStateJson['lastOpenedDate'];
          _lastOpenedDate =
              lastOpenedDateStr != null
                  ? DateTime.parse(lastOpenedDateStr)
                  : null;
          _appOpenCount = appStateJson['appOpenCount'] ?? 0;

          // Cleanup preferences
          _autoDeleteDays =
              appStateJson['autoDeleteDays'] ??
              AppConstants.defaultAutoDeleteDays;
          _lastDataCleanupDate = appStateJson['lastDataCleanupDate'] ?? 0;

          // Check if we're over free usage limit (for R1)
          if (_appOpenCount >= AppConstants.freeUsageLimit) {
            _loggingService.info(
              'User has reached free usage limit: $_appOpenCount recordings',
            );
            // Will be handled by paywall service in R1
          }
        }
      }
    } catch (e, stackTrace) {
      _handleError('Failed to load app state', e, stackTrace);

      // Use defaults if loading fails
      _themeMode = ThemeMode.system;
      _textSizeLevel = TextSizeLevel.normal;
      _hasCompletedOnboarding = false;
      _hasAcceptedPrivacyPolicy = false;
      _isCloudSyncEnabled = false;
      _selectedCloudProvider = null;
      _isHighContrastEnabled = false;
      _isVoicePromptEnabled = true;
      _lastOpenedDate = null;
      _appOpenCount = 0;
      _autoDeleteDays = AppConstants.defaultAutoDeleteDays;
      _lastDataCleanupDate = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize the app state file path.
  Future<void> _initializeAppStateFile() async {
    // Always call initialize on LocalStorageService
    // The method handles the case if it's already initialized
    await _localStorageService.initialize();

    final appDocDir = await getApplicationDocumentsDirectory();
    final appSettingsDir = Directory(
      path.join(appDocDir.path, _appSettingsDirName),
    );

    if (!await appSettingsDir.exists()) {
      await appSettingsDir.create(recursive: true);
    }

    _appStateFilePath = path.join(appSettingsDir.path, _appStateFileName);
  }

  /// Saves the app state to storage.
  Future<void> _saveAppState() async {
    try {
      await _initializeAppStateFile();

      final appStateJson = {
        // Theme state
        'themeMode': _themeMode.toString(),
        'textSizeLevel': _textSizeLevel.toString(),

        // Onboarding state
        'hasCompletedOnboarding': _hasCompletedOnboarding,

        // Privacy preferences
        'hasAcceptedPrivacyPolicy': _hasAcceptedPrivacyPolicy,
        'isCloudSyncEnabled': _isCloudSyncEnabled,
        'selectedCloudProvider': _selectedCloudProvider?.toString(),

        // Accessibility preferences
        'isHighContrastEnabled': _isHighContrastEnabled,
        'isVoicePromptEnabled': _isVoicePromptEnabled,

        // Usage statistics
        'lastOpenedDate': _lastOpenedDate?.toIso8601String(),
        'appOpenCount': _appOpenCount,

        // Cleanup preferences
        'autoDeleteDays': _autoDeleteDays,
        'lastDataCleanupDate': _lastDataCleanupDate,
      };

      final File file = File(_appStateFilePath);
      await file.writeAsString(jsonEncode(appStateJson));
    } catch (e, stackTrace) {
      _loggingService.error('Failed to save app state', e, stackTrace);
    }
  }

  /// Parses a ThemeMode from a string.
  ThemeMode _parseThemeMode(String? value) {
    if (value == null) return ThemeMode.system;

    switch (value) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }

  /// Parses a TextSizeLevel from a string.
  TextSizeLevel _parseTextSizeLevel(String? value) {
    if (value == null) return TextSizeLevel.normal;

    switch (value) {
      case 'TextSizeLevel.small':
        return TextSizeLevel.small;
      case 'TextSizeLevel.normal':
        return TextSizeLevel.normal;
      case 'TextSizeLevel.large':
        return TextSizeLevel.large;
      case 'TextSizeLevel.extraLarge':
        return TextSizeLevel.extraLarge;
      default:
        return TextSizeLevel.normal;
    }
  }

  /// Parses a CloudStorageProvider from a string.
  CloudStorageProvider? _parseCloudProvider(String? value) {
    if (value == null) return null;

    switch (value) {
      case 'CloudStorageProvider.iCloud':
        return CloudStorageProvider.iCloud;
      case 'CloudStorageProvider.googleDrive':
        return CloudStorageProvider.googleDrive;
      case 'CloudStorageProvider.oneDrive':
        return CloudStorageProvider.oneDrive;
      default:
        return null;
    }
  }

  /// Handles errors by logging them and updating error state.
  void _handleError(String message, Object error, StackTrace stackTrace) {
    if (error is MiloException) {
      _errorMessage = error.message;
    } else {
      _errorMessage = message;
    }

    _loggingService.error(message, error, stackTrace);
  }
}
