/*
file path: /hey_milo/lib/services/logging_service.dart
Service- Milo App
This service centralizes logging throughout the app, providing consistent
formatting, levels, and potentially local file logging for debugging.
Author: Milo App Development Team
Last Updated: May 4, 2025*/
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Log levels for the application
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  fatal,
}

/// A service that handles logging throughout the application
class LoggingService {
  // Internal logger state
  bool _isInitialized = false;
  File? _logFile;
  LogLevel _currentLogLevel = LogLevel.verbose;

  /// Initialize the logging service
  ///
  /// Sets up the logger with appropriate level based on environment.
  /// Optionally configures file logging for persistent logs on the device.
  Future<void> initialize({bool enableFileLogging = !kReleaseMode}) async {
    try {
      // Configure appropriate log level based on build mode
      _currentLogLevel = kReleaseMode ? LogLevel.warning : LogLevel.verbose;

      // Create log file if file logging is enabled
      if (enableFileLogging) {
        // Use a simple app documents directory approach that doesn't rely on path_provider
        // We'll just use the app's temporary directory for logs in this MVP
        final Directory appDocDir = Directory.systemTemp.createTempSync('milo_logs');
        final logDirPath = appDocDir.path;

        // Create logs directory if it doesn't exist
        final logDir = Directory(logDirPath);
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        // Create or get existing log file with current date
        final now = DateTime.now();
        final fileName = 'milo_${now.year}-${now.month}-${now.day}.log';
        _logFile = File('$logDirPath/$fileName');
      }

      _isInitialized = true;
      debug('LoggingService initialized successfully');
    } catch (e) {
      // Log the initialization error
      error('Failed to initialize LoggingService: $e');

      // Initialize with minimum functionality
      _isInitialized = true;
    }
  }

  /// Log a verbose message
  ///
  /// Use for highly detailed tracing, visible only during development
  void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.verbose, message, error, stackTrace);
  }

  /// Log a debug message
  ///
  /// Use for detailed information that is helpful during development
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log an info message
  ///
  /// Use for general information about app operation
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a warning message
  ///
  /// Use for potentially problematic situations that don't cause immediate failure
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message
  ///
  /// Use for errors that prevent normal operation but don't crash the app
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Log a critical error message
  ///
  /// Use for critical failures that may lead to app crashes
  void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error, stackTrace);
  }

  /// Log an exception with appropriate context
  ///
  /// Specialized method for logging MiloException with proper categorization
  void logException(Exception exception, {String? context, StackTrace? stackTrace}) {
    _ensureInitialized();

    final message = context != null
        ? '$context: ${exception.toString()}'
        : exception.toString();

    // Log with appropriate level based on exception type
    if (exception.toString().contains('AudioException') ||
        exception.toString().contains('StorageException') ||
        exception.toString().contains('CloudAuthException')) {
      error(message, exception, stackTrace);
    } else if (exception.toString().contains('PermissionException') ||
        exception.toString().contains('NotificationException')) {
      warning(message, exception, stackTrace);
    } else {
      // Default to error level for other exception types
      error(message, exception, stackTrace);
    }
  }

  /// Internal logging implementation
  ///
  /// Formats the log entry and writes it to appropriate outputs
  void _log(LogLevel level, String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();

    // Skip if the current log level is more restrictive
    if (_shouldSkipLog(level)) {
      return;
    }

    // Format the log message
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final levelString = _getLevelString(level);
    final stackTraceString = stackTrace != null ? '\n${stackTrace.toString()}' : '';
    final errorString = error != null ? '\n${error.toString()}' : '';

    final logEntry = '[$timestamp] $levelString: $message$errorString$stackTraceString';

    // Output to console
    _printToConsole(level, logEntry);

    // Write to file if enabled
    _writeToFile(logEntry);
  }

  /// Ensures the service is initialized before use
  ///
  /// Creates a default configuration if not properly initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      _currentLogLevel = kReleaseMode ? LogLevel.error : LogLevel.debug;
      _isInitialized = true;
    }
  }

  /// Determine if a log entry should be skipped based on current log level
  ///
  /// @param level The level of the current log entry
  /// @return bool True if the entry should be skipped
  bool _shouldSkipLog(LogLevel level) {
    return level.index < _currentLogLevel.index;
  }

  /// Get a string representation of a log level
  ///
  /// @param level The log level
  /// @return String Formatted level string
  String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'VERBOSE';
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.fatal:
        return 'FATAL';
      }
  }

  /// Print a log entry to the console with appropriate formatting
  ///
  /// @param level The log level
  /// @param message The formatted log message
  void _printToConsole(LogLevel level, String message) {
    if (kReleaseMode) {
      // In release mode, only print warnings and errors
      if (level.index >= LogLevel.warning.index) {
        // ignore: avoid_print
        print(message);
      }
    } else {
      // In debug mode, print with colors when available
      if (level == LogLevel.error || level == LogLevel.fatal) {
        // ignore: avoid_print
        print('\x1B[31m$message\x1B[0m'); // Red
      } else if (level == LogLevel.warning) {
        // ignore: avoid_print
        print('\x1B[33m$message\x1B[0m'); // Yellow
      } else if (level == LogLevel.info) {
        // ignore: avoid_print
        print('\x1B[36m$message\x1B[0m'); // Cyan
      } else {
        // ignore: avoid_print
        print(message); // Normal
      }
    }
  }

  /// Write a log entry to the log file if file logging is enabled
  ///
  /// @param message The formatted log message
  Future<void> _writeToFile(String message) async {
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(
          '$message\n',
          mode: FileMode.append,
          flush: true, // Ensure logs are written immediately
        );
      } catch (e) {
        // Silent failure for log file writing errors
        // We don't want logging errors to cause further issues
      }
    }
  }

  /// Get the log file path
  ///
  /// @return The path to the current log file, or null if file logging is disabled
  String? getLogFilePath() {
    return _logFile?.path;
  }

  /// Clear all log files that are older than the specified number of days
  ///
  /// @param days Number of days to keep logs for (default: 7)
  /// @return The number of log files deleted
  Future<int> clearOldLogs({int days = 7}) async {
    try {
      if (_logFile == null) return 0;

      final logDirPath = _logFile!.parent.path;
      final logDir = Directory(logDirPath);

      if (!await logDir.exists()) return 0;

      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      int deletedCount = 0;

      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final fileName = entity.path.split('/').last;
          // Parse date from filename format milo_YYYY-MM-DD.log
          if (fileName.startsWith('milo_')) {
            try {
              final dateStr = fileName.substring(5, 15);
              final dateParts = dateStr.split('-');
              if (dateParts.length == 3) {
                final fileDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );

                if (fileDate.isBefore(cutoffDate)) {
                  await entity.delete();
                  deletedCount++;
                }
              }
            } catch (e) {
              // If parsing fails, skip this file
              warning('Failed to parse date from log filename: $fileName');
            }
          }
        }
      }

      info('Cleared $deletedCount old log files');
      return deletedCount;
    } catch (e) {
      error('Failed to clear old logs: $e');
      return 0;
    }
  }
}