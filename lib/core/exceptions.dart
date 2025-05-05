// Project: Milo App
// File: core/exceptions.dart
// Purpose: Custom exceptions hierarchy for the application
// Date: May 4, 2025

/// Base exception class for the Milo application.
///
/// All custom exceptions in the application should extend this class
/// to ensure consistent error handling and reporting.
class MiloException implements Exception {
  /// Unique error code identifying the exception type
  final String code;

  /// Human-readable error message
  final String message;

  /// Technical details for debugging (not shown to users)
  final String technicalDetail;

  /// Stack trace where the exception occurred
  final StackTrace? stackTrace;

  /// Whether the exception should be reported to the user
  final bool shouldNotifyUser;

  /// Creates a new [MiloException]
  ///
  /// [code] is required and should follow the format "CATEGORY_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const MiloException({
    required this.code,
    required this.message,
    this.technicalDetail = '',
    this.stackTrace,
    this.shouldNotifyUser = true,
  });

  @override
  String toString() {
    return 'MiloException: [$code] $message${technicalDetail.isNotEmpty ? ' - $technicalDetail' : ''}';
  }
}

/// Exception thrown when audio recording or playback fails
class AudioException extends MiloException {
  /// Creates a new [AudioException]
  ///
  /// [code] should follow the format "AUDIO_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const AudioException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when microphone access is denied
  factory AudioException.permissionDenied({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return AudioException(
      code: 'AUDIO_PERMISSION_DENIED',
      message: 'Microphone access is required for recording memories',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when recording initialization fails
  factory AudioException.recordingInitFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return AudioException(
      code: 'AUDIO_RECORDING_INIT_FAILED',
      message: 'Unable to start recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when recording fails during operation
  factory AudioException.recordingFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return AudioException(
      code: 'AUDIO_RECORDING_FAILED',
      message: 'Recording failed, please try again',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when playback fails
  factory AudioException.playbackFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return AudioException(
      code: 'AUDIO_PLAYBACK_FAILED',
      message: 'Unable to play this recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}

/// Exception thrown when storage operations fail
class StorageException extends MiloException {
  /// Creates a new [StorageException]
  ///
  /// [code] should follow the format "STORAGE_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const StorageException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when storage permission is denied
  factory StorageException.permissionDenied({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return StorageException(
      code: 'STORAGE_PERMISSION_DENIED',
      message: 'Storage access is required to save recordings',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when storage is full or unavailable
  factory StorageException.storageFull({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return StorageException(
      code: 'STORAGE_FULL',
      message: 'Not enough space to save recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when file writing fails
  factory StorageException.writeError({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return StorageException(
      code: 'STORAGE_WRITE_ERROR',
      message: 'Failed to save recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when file reading fails
  factory StorageException.readError({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return StorageException(
      code: 'STORAGE_READ_ERROR',
      message: 'Failed to load recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when file deletion fails
  factory StorageException.deleteError({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return StorageException(
      code: 'STORAGE_DELETE_ERROR',
      message: 'Failed to delete recording',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}

/// Exception thrown when permission requests fail
class PermissionException extends MiloException {
  /// Creates a new [PermissionException]
  ///
  /// [code] should follow the format "PERMISSION_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const PermissionException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when a permission is permanently denied
  factory PermissionException.permanentlyDenied({
    required String permissionName,
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return PermissionException(
      code: 'PERMISSION_PERMANENTLY_DENIED',
      message: '$permissionName access has been permanently denied. Please enable it in device settings.',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when a permission request is denied by the user
  factory PermissionException.denied({
    required String permissionName,
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return PermissionException(
      code: 'PERMISSION_DENIED',
      message: '$permissionName access is needed for this feature',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when a permission cannot be requested
  factory PermissionException.requestFailed({
    required String permissionName,
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return PermissionException(
      code: 'PERMISSION_REQUEST_FAILED',
      message: 'Unable to request $permissionName access',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}

/// Exception thrown when notification operations fail
class NotificationException extends MiloException {
  /// Creates a new [NotificationException]
  ///
  /// [code] should follow the format "NOTIFICATION_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
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

/// Exception thrown when cloud storage operations fail
class CloudStorageException extends MiloException {
  /// Creates a new [CloudStorageException]
  ///
  /// [code] should follow the format "CLOUD_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const CloudStorageException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when authentication fails
  factory CloudStorageException.authFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return CloudStorageException(
      code: 'CLOUD_AUTH_FAILED',
      message: 'Failed to sign in to cloud storage',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when uploading a file fails
  factory CloudStorageException.uploadFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return CloudStorageException(
      code: 'CLOUD_UPLOAD_FAILED',
      message: 'Failed to upload to cloud storage',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when network connection is unavailable
  factory CloudStorageException.networkUnavailable({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return CloudStorageException(
      code: 'CLOUD_NETWORK_UNAVAILABLE',
      message: 'Network connection unavailable',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}

/// Exception thrown when database operations fail
class DatabaseException extends MiloException {
  /// Creates a new [DatabaseException]
  ///
  /// [code] should follow the format "DB_SPECIFIC_ERROR"
  /// [message] is a user-friendly message that can be displayed in the UI
  /// [technicalDetail] provides additional information for developers/logs
  /// [stackTrace] the stack trace where the exception was thrown
  /// [shouldNotifyUser] determines if this exception should be shown to the user
  const DatabaseException({
    required super.code,
    required super.message,
    super.technicalDetail,
    super.stackTrace,
    super.shouldNotifyUser,
  });

  /// Exception for when database initialization fails
  factory DatabaseException.initFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      code: 'DB_INIT_FAILED',
      message: 'Failed to initialize database',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
      // This likely requires app restart, so definitely notify
      shouldNotifyUser: true,
    );
  }

  /// Exception for when a database query fails
  factory DatabaseException.queryFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      code: 'DB_QUERY_FAILED',
      message: 'Failed to retrieve data',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when a database insert fails
  factory DatabaseException.insertFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      code: 'DB_INSERT_FAILED',
      message: 'Failed to save data',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when a database update fails
  factory DatabaseException.updateFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      code: 'DB_UPDATE_FAILED',
      message: 'Failed to update data',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }

  /// Exception for when a database delete fails
  factory DatabaseException.deleteFailed({
    String technicalDetail = '',
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      code: 'DB_DELETE_FAILED',
      message: 'Failed to delete data',
      technicalDetail: technicalDetail,
      stackTrace: stackTrace,
    );
  }
}