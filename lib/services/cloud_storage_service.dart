/*
* File: lib/services/cloud_storage_service.dart
* Description: Service for handling user-controlled cloud storage backup
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:async';
import 'package:get_it/get_it.dart';

import '../core/exceptions.dart';
import '../models/memory_model.dart';
import '../services/logging_service.dart';
import '../services/local_storage_service.dart';
import '../providers/app_state_provider.dart';

/// Represents the available cloud storage providers.
enum CloudProvider {
  /// Apple iCloud
  icloud,

  /// Google Drive
  googleDrive,

  /// Microsoft OneDrive
  oneDrive
}

/// Status of a cloud operation.
enum CloudOperationStatus {
  /// Operation completed successfully
  success,

  /// Operation is in progress
  inProgress,

  /// Operation failed
  failed,

  /// Operation was cancelled
  cancelled,

  /// User authentication failed
  authFailed,

  /// No internet connection
  noConnection
}

/// Result of a cloud operation.
class CloudOperationResult {
  /// Status of the operation
  final CloudOperationStatus status;

  /// Message describing the result
  final String message;

  /// Details about the operation (optional)
  final Map<String, dynamic>? details;

  /// Creates a new CloudOperationResult.
  CloudOperationResult({
    required this.status,
    required this.message,
    this.details,
  });

  /// Creates a success result.
  factory CloudOperationResult.success({
    String message = 'Operation completed successfully',
    Map<String, dynamic>? details,
  }) {
    return CloudOperationResult(
      status: CloudOperationStatus.success,
      message: message,
      details: details,
    );
  }

  /// Creates a failure result.
  factory CloudOperationResult.failure({
    String message = 'Operation failed',
    Map<String, dynamic>? details,
  }) {
    return CloudOperationResult(
      status: CloudOperationStatus.failed,
      message: message,
      details: details,
    );
  }

  /// Creates an auth failure result.
  factory CloudOperationResult.authFailure({
    String message = 'Authentication failed',
    Map<String, dynamic>? details,
  }) {
    return CloudOperationResult(
      status: CloudOperationStatus.authFailed,
      message: message,
      details: details,
    );
  }

  /// Creates an in progress result.
  factory CloudOperationResult.inProgress({
    String message = 'Operation in progress',
    Map<String, dynamic>? details,
  }) {
    return CloudOperationResult(
      status: CloudOperationStatus.inProgress,
      message: message,
      details: details,
    );
  }

  /// Whether the operation was successful.
  bool get isSuccess => status == CloudOperationStatus.success;

  /// Whether the operation failed.
  bool get isFailure => status == CloudOperationStatus.failed ||
      status == CloudOperationStatus.authFailed ||
      status == CloudOperationStatus.noConnection;
}

/// Service responsible for handling cloud storage operations.
///
/// This service enables users to back up their data to their personal
/// cloud storage accounts. No user data is sent to Milo's servers.
/// The app only facilitates the backup process to the user's own accounts.
///
/// This service handles:
/// - Authentication with cloud storage providers
/// - Backing up memory recordings to cloud storage
/// - Restoring memory recordings from cloud storage
/// - Synchronizing data between device and cloud
class CloudStorageService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final LocalStorageService _localStorageService;
  final AppStateProvider _appStateProvider;

  bool _isInitialized = false;
  bool _isAuthenticatedGoogle = false;
  bool _isAuthenticatedApple = false;
  bool _isAuthenticatedMicrosoft = false;

  // For MVP, we'll use a mock implementation without actual cloud integrations
  // These will be replaced with real implementations in future versions

  /// Creates a new CloudStorageService instance.
  CloudStorageService({
    required LocalStorageService localStorageService,
    required AppStateProvider appStateProvider,
  }) :
        _localStorageService = localStorageService,
        _appStateProvider = appStateProvider;

  /// Initializes the cloud storage service.
  ///
  /// This must be called before any cloud operations can be performed.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('CloudStorageService: Initializing cloud storage service');

      await _localStorageService.initialize();

      // Check if cloud sync is enabled in app state
      final isCloudSyncEnabled = _appStateProvider.isCloudSyncEnabled;
      final selectedProvider = _appStateProvider.selectedCloudProvider;

      if (isCloudSyncEnabled && selectedProvider != null) {
        _logger.info('CloudStorageService: Cloud sync is enabled for provider: $selectedProvider');

        // For MVP, we won't actually connect to cloud services
        // This will be implemented in future versions
      } else {
        _logger.info('CloudStorageService: Cloud sync is disabled');
      }

      _isInitialized = true;
      _logger.info('CloudStorageService: Successfully initialized');
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to initialize cloud storage service', e, stackTrace);
      throw CloudStorageException(
        code: 'CLOUD_STORAGE_INIT_FAILED',
        message: 'Failed to initialize cloud storage service',
      );
    }
  }

  /// Authenticates with a cloud storage provider.
  ///
  /// [provider] The cloud provider to authenticate with.
  /// Returns the result of the authentication operation.
  Future<CloudOperationResult> authenticate(CloudProvider provider) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Authenticating with $provider');

      // For MVP, we'll simulate a successful authentication
      // In a real implementation, this would launch the OAuth flow

      switch (provider) {
        case CloudProvider.icloud:
          await Future.delayed(const Duration(seconds: 1));
          _isAuthenticatedApple = true;

          // Since auth was successful, update app state with the selected provider
          await _appStateProvider.setCloudSync(true, provider: CloudStorageProvider.iCloud);

          return CloudOperationResult.success(
            message: 'Successfully authenticated with iCloud',
          );

        case CloudProvider.googleDrive:
          await Future.delayed(const Duration(seconds: 1));
          _isAuthenticatedGoogle = true;

          // Since auth was successful, update app state with the selected provider
          await _appStateProvider.setCloudSync(true, provider: CloudStorageProvider.googleDrive);

          return CloudOperationResult.success(
            message: 'Successfully authenticated with Google Drive',
          );

        case CloudProvider.oneDrive:
          await Future.delayed(const Duration(seconds: 1));
          _isAuthenticatedMicrosoft = true;

          // Since auth was successful, update app state with the selected provider
          await _appStateProvider.setCloudSync(true, provider: CloudStorageProvider.oneDrive);

          return CloudOperationResult.success(
            message: 'Successfully authenticated with OneDrive',
          );
      }
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Authentication failed with $provider', e, stackTrace);

      return CloudOperationResult.authFailure(
        message: 'Failed to authenticate with $provider: ${e.toString()}',
      );
    }
  }

  /// Checks if the user is authenticated with the specified provider.
  ///
  /// [provider] The cloud provider to check authentication for.
  /// Returns true if authenticated, false otherwise.
  Future<bool> isAuthenticated(CloudProvider provider) async {
    if (!_isInitialized) await initialize();

    switch (provider) {
      case CloudProvider.icloud:
        return _isAuthenticatedApple;
      case CloudProvider.googleDrive:
        return _isAuthenticatedGoogle;
      case CloudProvider.oneDrive:
        return _isAuthenticatedMicrosoft;
    }
  }

  /// Signs out from the cloud storage provider.
  ///
  /// [provider] The cloud provider to sign out from.
  /// Returns the result of the operation.
  Future<CloudOperationResult> signOut(CloudProvider provider) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Signing out from $provider');

      switch (provider) {
        case CloudProvider.icloud:
          await Future.delayed(const Duration(milliseconds: 500));
          _isAuthenticatedApple = false;
          break;
        case CloudProvider.googleDrive:
          await Future.delayed(const Duration(milliseconds: 500));
          _isAuthenticatedGoogle = false;
          break;
        case CloudProvider.oneDrive:
          await Future.delayed(const Duration(milliseconds: 500));
          _isAuthenticatedMicrosoft = false;
          break;
      }

      // Disable cloud sync in app state
      await _appStateProvider.setCloudSync(false);

      return CloudOperationResult.success(
        message: 'Successfully signed out from $provider',
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to sign out from $provider', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to sign out from $provider: ${e.toString()}',
      );
    }
  }

  /// Backs up a memory recording to cloud storage.
  ///
  /// [memory] The memory recording to back up.
  /// Returns the result of the backup operation.
  Future<CloudOperationResult> backupMemory(Memory memory) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Backing up memory ${memory.id}');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would upload the file to the cloud
      // For MVP, we'll just simulate a successful upload

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Create a mock cloud path
      final cloudPath = 'milo_backups/memories/${memory.id}.m4a';

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully backed up memory recording',
        details: {
          'cloudPath': cloudPath,
          'provider': provider.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to backup memory ${memory.id}', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to backup memory recording: ${e.toString()}',
      );
    }
  }

  /// Restores a memory recording from cloud storage.
  ///
  /// [memoryId] The ID of the memory recording to restore.
  /// [cloudPath] The path to the file in cloud storage.
  /// Returns the result of the restore operation.
  Future<CloudOperationResult> restoreMemory(String memoryId, String cloudPath) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Restoring memory $memoryId from cloud');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would download the file from the cloud
      // For MVP, we'll just simulate a successful download

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully restored memory recording',
        details: {
          'memoryId': memoryId,
          'cloudPath': cloudPath,
          'provider': provider.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to restore memory $memoryId', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to restore memory recording: ${e.toString()}',
      );
    }
  }

  /// Synchronizes all memory recordings with cloud storage.
  ///
  /// [memories] List of all memory recordings.
  /// [onProgress] Callback for progress updates.
  /// Returns the result of the sync operation.
  Future<CloudOperationResult> syncMemories(
      List<Memory> memories, {
        Function(double progress, String message)? onProgress,
      }) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Syncing ${memories.length} memories with cloud');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // For MVP, we'll simulate syncing
      // In a real implementation, this would:
      // 1. Compare local files with cloud files
      // 2. Upload new/changed files
      // 3. Download any files from cloud not present locally

      final total = memories.length;

      for (int i = 0; i < total; i++) {
        // Simulate network delay for each file
        await Future.delayed(const Duration(milliseconds: 200));

        // Calculate progress
        final progress = (i + 1) / total;

        // Call progress callback if provided
        if (onProgress != null) {
          onProgress(
            progress,
            'Syncing memory ${i + 1} of $total',
          );
        }
      }

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully synced ${memories.length} memory recordings',
        details: {
          'syncedCount': memories.length,
          'provider': provider.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to sync memories', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to sync memory recordings: ${e.toString()}',
      );
    }
  }

  /// Deletes a memory recording from cloud storage.
  ///
  /// [memoryId] The ID of the memory recording to delete.
  /// [cloudPath] The path to the file in cloud storage.
  /// Returns the result of the delete operation.
  Future<CloudOperationResult> deleteFromCloud(String memoryId, String cloudPath) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Deleting memory $memoryId from cloud');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would delete the file from the cloud
      // For MVP, we'll just simulate a successful deletion

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully deleted memory recording from cloud',
        details: {
          'memoryId': memoryId,
          'cloudPath': cloudPath,
          'provider': provider.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to delete memory $memoryId from cloud', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to delete memory recording from cloud: ${e.toString()}',
      );
    }
  }

  /// Gets a list of all backup files available in cloud storage.
  ///
  /// Returns a list of available backup files.
  Future<CloudOperationResult> listCloudBackups() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Listing cloud backups');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would list files from the cloud
      // For MVP, we'll just return a mock list of backups

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Create mock backup list
      final backups = List.generate(5, (index) {
        final date = DateTime.now().subtract(Duration(days: index));
        return {
          'id': 'backup_${date.millisecondsSinceEpoch}',
          'name': 'Backup ${date.toIso8601String().split('T')[0]}',
          'date': date.toIso8601String(),
          'size': 1024 * 1024 * (5 - index), // Mock size in bytes
          'fileCount': 10 - index,
        };
      });

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully retrieved cloud backups',
        details: {
          'backups': backups,
          'provider': provider.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to list cloud backups', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to list cloud backups: ${e.toString()}',
      );
    }
  }

  /// Creates a full backup of all app data to cloud storage.
  ///
  /// [onProgress] Callback for progress updates.
  /// Returns the result of the backup operation.
  Future<CloudOperationResult> createFullBackup({
    Function(double progress, String message)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Creating full backup');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would create a backup package and upload it
      // For MVP, we'll simulate the backup process

      // Simulate initial preparation
      if (onProgress != null) {
        onProgress(0.0, 'Preparing backup...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate backing up memory recordings
      if (onProgress != null) {
        onProgress(0.2, 'Backing up memory recordings...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate backing up medications
      if (onProgress != null) {
        onProgress(0.4, 'Backing up medications...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate backing up caregiver messages
      if (onProgress != null) {
        onProgress(0.6, 'Backing up caregiver messages...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate backing up settings
      if (onProgress != null) {
        onProgress(0.8, 'Backing up settings...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate finalizing backup
      if (onProgress != null) {
        onProgress(0.95, 'Finalizing backup...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate completion
      if (onProgress != null) {
        onProgress(1.0, 'Backup completed successfully!');
      }

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully created full backup',
        details: {
          'backupId': 'backup_${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': DateTime.now().toIso8601String(),
          'provider': provider.toString(),
          'size': 1024 * 1024 * 10, // Mock size: 10MB
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to create full backup', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to create full backup: ${e.toString()}',
      );
    }
  }

  /// Restores app data from a cloud backup.
  ///
  /// [backupId] The ID of the backup to restore.
  /// [onProgress] Callback for progress updates.
  /// Returns the result of the restore operation.
  Future<CloudOperationResult> restoreFromBackup(
      String backupId, {
        Function(double progress, String message)? onProgress,
      }) async {
    if (!_isInitialized) await initialize();

    try {
      _logger.info('CloudStorageService: Restoring from backup $backupId');

      // Check if cloud sync is enabled
      if (!_appStateProvider.isCloudSyncEnabled) {
        return CloudOperationResult.failure(
          message: 'Cloud sync is not enabled. Please enable it in settings.',
        );
      }

      // Check if authenticated with the selected provider
      final provider = _getSelectedProvider();
      if (provider == null) {
        return CloudOperationResult.authFailure(
          message: 'No cloud provider selected. Please select a provider in settings.',
        );
      }

      final isAuth = await isAuthenticated(provider);
      if (!isAuth) {
        return CloudOperationResult.authFailure(
          message: 'Not authenticated with $provider. Please sign in first.',
        );
      }

      // In the real implementation, this would download and restore a backup
      // For MVP, we'll simulate the restore process

      // Simulate initial preparation
      if (onProgress != null) {
        onProgress(0.0, 'Preparing to restore...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate downloading backup
      if (onProgress != null) {
        onProgress(0.2, 'Downloading backup...');
      }
      await Future.delayed(const Duration(seconds: 2));

      // Simulate restoring memory recordings
      if (onProgress != null) {
        onProgress(0.4, 'Restoring memory recordings...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate restoring medications
      if (onProgress != null) {
        onProgress(0.6, 'Restoring medications...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate restoring caregiver messages
      if (onProgress != null) {
        onProgress(0.8, 'Restoring caregiver messages...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate restoring settings
      if (onProgress != null) {
        onProgress(0.9, 'Restoring settings...');
      }
      await Future.delayed(const Duration(seconds: 1));

      // Simulate completion
      if (onProgress != null) {
        onProgress(1.0, 'Restore completed successfully!');
      }

      // Return a successful result
      return CloudOperationResult.success(
        message: 'Successfully restored from backup',
        details: {
          'backupId': backupId,
          'timestamp': DateTime.now().toIso8601String(),
          'provider': provider.toString(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('CloudStorageService: Failed to restore from backup $backupId', e, stackTrace);

      return CloudOperationResult.failure(
        message: 'Failed to restore from backup: ${e.toString()}',
      );
    }
  }

  /// Gets the selected cloud provider from app state.
  CloudProvider? _getSelectedProvider() {
    final selectedProvider = _appStateProvider.selectedCloudProvider;

    if (selectedProvider == null) {
      return null;
    }

    switch (selectedProvider) {
      case CloudStorageProvider.iCloud:
        return CloudProvider.icloud;
      case CloudStorageProvider.googleDrive:
        return CloudProvider.googleDrive;
      case CloudStorageProvider.oneDrive:
        return CloudProvider.oneDrive;
      }
  }
}

/// Custom exception for cloud storage errors
class CloudStorageException extends MiloException {
  /// Creates a new CloudStorageException
  const CloudStorageException({
    required super.code,
    required super.message,
    super.technicalDetail,  // Make non-nullable with default value
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when cloud authentication fails
  factory CloudStorageException.authFailed({
    String provider = 'cloud service',
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return CloudStorageException(
      code: 'CLOUD_AUTH_FAILED',
      message: 'Authentication failed with $provider. Please sign in again.',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when cloud operation fails due to network issues
  factory CloudStorageException.networkError({
    String operation = 'cloud operation',
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return CloudStorageException(
      code: 'CLOUD_NETWORK_ERROR',
      message: 'Network error during $operation. Please check your internet connection.',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}