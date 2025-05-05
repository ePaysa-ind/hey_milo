/*
* File: lib/services/cleanup_service.dart
* Description: Service for managing data cleanup and maintenance in the Milo App
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:io';
import 'package:get_it/get_it.dart';

import '../core/exceptions.dart';
import '../config/constants.dart';
import '../services/logging_service.dart';
import '../services/local_storage_service.dart';
import '../providers/app_state_provider.dart';
import '../providers/recordings_provider.dart';

/// Service responsible for managing data cleanup and maintenance.
///
/// This service handles:
/// - Deletion of old recordings based on retention policy
/// - Cleanup of temporary files
/// - Maintenance of app storage
/// - Log file rotation and cleanup
class CleanupService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final LocalStorageService _localStorageService;
  final RecordingsProvider _recordingsProvider;
  final AppStateProvider _appStateProvider;

  bool _isInitialized = false;
  DateTime? _lastCleanupDate;

  /// Creates a new CleanupService instance.
  CleanupService({
    required LocalStorageService localStorageService,
    required RecordingsProvider recordingsProvider,
    required AppStateProvider appStateProvider,
  }) :
        _localStorageService = localStorageService,
        _recordingsProvider = recordingsProvider,
        _appStateProvider = appStateProvider;

  /// Initializes the cleanup service.
  ///
  /// This must be called before any cleanup operations can be performed.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('CleanupService: Initializing cleanup service');

      await _localStorageService.initialize();

      // Get the last cleanup date from app state
      final lastCleanupTimestamp = _appStateProvider.lastDataCleanupDate;
      _lastCleanupDate = lastCleanupTimestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastCleanupTimestamp)
          : null;

      _isInitialized = true;
      _logger.info('CleanupService: Successfully initialized');
    } catch (e, stackTrace) {
      _logger.error('CleanupService: Failed to initialize cleanup service', e, stackTrace);
      throw StorageException(
        code: 'CLEANUP_SERVICE_INIT_FAILED',
        message: 'Failed to initialize cleanup service',
      );
    }
  }

  /// Performs a full cleanup based on configured retention policies.
  ///
  /// [force] If true, performs cleanup regardless of the last cleanup date.
  /// Returns the number of items cleaned up.
  Future<int> performScheduledCleanup({bool force = false}) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if we need to run a cleanup based on interval
      final now = DateTime.now();
      if (!force && _lastCleanupDate != null) {
        final daysSinceLastCleanup = now.difference(_lastCleanupDate!).inDays;
        if (daysSinceLastCleanup < AppConstants.cleanupIntervalDays) {
          _logger.info('CleanupService: Skipping scheduled cleanup, last run was $daysSinceLastCleanup days ago');
          return 0;
        }
      }

      _logger.info('CleanupService: Running scheduled cleanup');

      int totalCleanedItems = 0;

      // Cleanup old recordings based on retention policy
      final cleanedRecordings = await cleanupOldRecordings();
      totalCleanedItems += cleanedRecordings;

      // Cleanup temporary files
      final cleanedTempFiles = await cleanupTemporaryFiles();
      totalCleanedItems += cleanedTempFiles;

      // Cleanup old log files
      final cleanedLogFiles = await _logger.clearOldLogs(days: AppConstants.logRetentionDays);
      totalCleanedItems += cleanedLogFiles;

      // Update last cleanup date
      _lastCleanupDate = now;
      await _appStateProvider.updateLastDataCleanupDate();

      _logger.info('CleanupService: Completed scheduled cleanup, removed $totalCleanedItems items');
      return totalCleanedItems;
    } catch (e, stackTrace) {
      _logger.error('CleanupService: Failed to perform scheduled cleanup', e, stackTrace);
      throw StorageException(
        code: 'CLEANUP_FAILED',
        message: 'Failed to perform data cleanup',
      );
    }
  }

  /// Cleans up old recordings based on the configured retention policy.
  ///
  /// Returns the number of recordings cleaned up.
  Future<int> cleanupOldRecordings() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CleanupService: Cleaning up old recordings');

      // Get retention policy from app state
      final retentionDays = _appStateProvider.autoDeleteDays;

      // If retention is set to 0, it means "never delete"
      if (retentionDays <= 0) {
        _logger.info('CleanupService: Auto-delete is disabled, skipping cleanup');
        return 0;
      }

      // Calculate cutoff date
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      // Get all memories - using loadMemoryEntries() which is the correct method in RecordingsProvider
      await _recordingsProvider.loadMemoryEntries();
      final allMemories = _recordingsProvider.memories;

      // Find recordings older than the cutoff date
      // Removed the isPinned check since it doesn't exist in the Memory model
      final oldRecordings = allMemories.where((memory) =>
      memory.timestamp.isBefore(cutoffDate) && !memory.isMarkedForDeletion
      ).toList();

      if (oldRecordings.isEmpty) {
        _logger.info('CleanupService: No old recordings to clean up');
        return 0;
      }

      // Delete old recordings
      int deletedCount = 0;
      for (final memory in oldRecordings) {
        try {
          // Using deleteMemoryEntry which is the correct method in RecordingsProvider
          final success = await _recordingsProvider.deleteMemoryEntry(memory.id);
          if (success) {
            deletedCount++;
          }
        } catch (e) {
          _logger.warning('CleanupService: Failed to delete memory ${memory.id}', e);
          // Continue with other deletions
        }
      }

      _logger.info('CleanupService: Cleaned up $deletedCount old recordings');
      return deletedCount;
    } catch (e, stackTrace) {
      _logger.error('CleanupService: Failed to clean up old recordings', e, stackTrace);
      throw StorageException(
        code: 'CLEANUP_RECORDINGS_FAILED',
        message: 'Failed to clean up old recordings',
      );
    }
  }

  /// Cleans up temporary files created by the app.
  ///
  /// Returns the number of temporary files cleaned up.
  Future<int> cleanupTemporaryFiles() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CleanupService: Cleaning up temporary files');

      // Get the app's temp directory
      final tempDir = Directory.systemTemp.createTempSync('milo_temp');
      if (!tempDir.existsSync()) {
        _logger.info('CleanupService: Temp directory does not exist, nothing to clean up');
        return 0;
      }

      // Find files older than the retention period (default 24 hours)
      final retentionHours = AppConstants.tempFileRetentionHours;
      final cutoffDate = DateTime.now().subtract(Duration(hours: retentionHours));

      int deletedCount = 0;
      final entities = tempDir.listSync(recursive: false, followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            final fileStat = entity.statSync();
            if (fileStat.modified.isBefore(cutoffDate)) {
              entity.deleteSync();
              deletedCount++;
            }
          } else if (entity is Directory) {
            // Check if directory is empty and old
            final dirStat = entity.statSync();
            if (dirStat.modified.isBefore(cutoffDate)) {
              final contents = entity.listSync();
              if (contents.isEmpty) {
                entity.deleteSync();
                deletedCount++;
              }
            }
          }
        } catch (e) {
          _logger.warning('CleanupService: Failed to delete temp file ${entity.path}', e);
          // Continue with other deletions
        }
      }

      _logger.info('CleanupService: Cleaned up $deletedCount temporary files and directories');
      return deletedCount;
    } catch (e, stackTrace) {
      _logger.error('CleanupService: Failed to clean up temporary files', e, stackTrace);
      throw StorageException(
        code: 'CLEANUP_TEMP_FILES_FAILED',
        message: 'Failed to clean up temporary files',
      );
    }
  }

  /// Calculates the storage usage for the app.
  ///
  /// Returns a map with storage statistics.
  Future<Map<String, dynamic>> calculateStorageUsage() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CleanupService: Calculating storage usage');

      final result = <String, dynamic>{
        'totalSizeBytes': 0,
        'recordingsSizeBytes': 0,
        'recordingsCount': 0,
        'otherFilesSizeBytes': 0,
        'otherFilesCount': 0,
      };

      // Get app documents directory
      final appDocDir = await _localStorageService.getAppDocumentsDirectory();

      // Calculate size recursively
      _calculateDirectorySize(appDocDir, result);

      _logger.info('CleanupService: Storage usage calculated, total: ${(result['totalSizeBytes'] / (1024 * 1024)).toStringAsFixed(2)} MB');
      return result;
    } catch (e, stackTrace) {
      _logger.error('CleanupService: Failed to calculate storage usage', e, stackTrace);
      throw StorageException(
        code: 'CALCULATE_STORAGE_FAILED',
        message: 'Failed to calculate storage usage',
      );
    }
  }

  /// Helper method to calculate the size of a directory recursively.
  void _calculateDirectorySize(Directory directory, Map<String, dynamic> result) {
    final entities = directory.listSync(recursive: false, followLinks: false);
    for (final entity in entities) {
      try {
        if (entity is File) {
          final size = entity.lengthSync();
          result['totalSizeBytes'] += size;

          // Check if it's a recording file
          if (entity.path.contains('recordings') &&
              entity.path.endsWith(AppConstants.recordingFileExtension)) {
            result['recordingsSizeBytes'] += size;
            result['recordingsCount']++;
          } else {
            result['otherFilesSizeBytes'] += size;
            result['otherFilesCount']++;
          }
        } else if (entity is Directory) {
          _calculateDirectorySize(entity, result);
        }
      } catch (e) {
        _logger.warning('CleanupService: Error calculating size for ${entity.path}', e);
        // Continue with other files
      }
    }
  }
}