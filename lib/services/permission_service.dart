/*
file path: lib/services/permission_service.dart
Permission Service for the Milo App
 Handles requesting and checking permissions required for app functionality:
 - Microphone for recording voice memories
 - Notifications for medication reminders
 - Storage for saving files (if needed on specific platforms)
 Author: Milo App Development Team
 Last Updated: May 4, 2025
*/
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Add the specific import path for permission_handler
import 'package:permission_handler/permission_handler.dart';
import '../config/constants.dart';
import '../config/strings.dart';
import '../core/exceptions.dart';

/// Service responsible for handling permission requests and checks
class PermissionService {
  // Dependencies
  final BuildContext? _context;

  // Permission status cache
  final Map<Permission, PermissionStatus> _permissionStatusCache = {};

  // Constructor
  PermissionService({BuildContext? context}) : _context = context;

  /* Request microphone permission
  @return Future-bool indicating if permission is granted
  @throws PermissionException if permission is denied permanently
  */
  Future<bool> requestMicrophonePermission() async {
    return _requestPermission(
      Permission.microphone,
      AppStrings.microphonePermissionTitle,
      AppStrings.microphonePermissionMessage,
    );
  }

  /*Request notification permission
  @return Future-bool indicating if permission is granted
  @throws PermissionException if permission is denied permanently
  */
  Future<bool> requestNotificationPermission() async {
    return _requestPermission(
      Permission.notification,
      AppStrings.notificationPermissionTitle,
      AppStrings.notificationPermissionMessage,
    );
  }

  /// Request storage permission (if needed on the platform)
  ///
  /// Note: Modern Android versions use scoped storage and iOS doesn't require
  /// explicit storage permission for app directory access. This is included
  /// for completeness and backwards compatibility.
  ///
  /// @return Future-bool indicating if permission is granted
  /// @throws PermissionException if permission is denied permanently
  Future<bool> requestStoragePermission() async {
    // On modern platforms, storage permission may not be needed for app directories
    if (kIsWeb) {
      return true; // Web doesn't need explicit storage permission
    }

    // For Android < 10, request legacy storage permission
    return _requestPermission(
      Permission.storage,
      AppStrings.storagePermissionTitle,
      AppStrings.storagePermissionMessage,
    );
  }

  /// Check if microphone permission is granted
  ///
  /// @return Future-bool indicating if permission is granted
  Future<bool> hasMicrophonePermission() async {
    return _checkPermission(Permission.microphone);
  }

  /// Check if notification permission is granted
  ///
  /// @return Future-bool indicating if permission is granted
  Future<bool> hasNotificationPermission() async {
    return _checkPermission(Permission.notification);
  }

  /// Check if storage permission is granted (if needed on platform)
  ///
  /// @return Future-bool indicating if permission is granted
  Future<bool> hasStoragePermission() async {
    if (kIsWeb) {
      return true; // Web doesn't need explicit storage permission
    }

    return _checkPermission(Permission.storage);
  }

  /// Generic method to request a permission with rationale
  ///
  /// Shows a dialog explaining why the permission is needed before requesting it.
  ///
  /// @param permission The permission to request
  /// @param title The title for the permission explanation dialog
  /// @param message The message explaining why the permission is needed
  /// @return Future-bool indicating if permission is granted
  /// @throws PermissionException if permission is denied permanently
  Future<bool> _requestPermission(
      Permission permission,
      String title,
      String message,
      ) async {
    // Check if already granted
    final status = await permission.status;
    _permissionStatusCache[permission] = status;

    if (status.isGranted) {
      return true;
    }

    // If permission was previously permanently denied, throw exception
    if (status.isPermanentlyDenied) {
      throw PermissionException(
        code: 'PERMISSION_PERMANENTLY_DENIED',
        message: '${permission.toString()} access has been permanently denied. Please enable it in device settings.',
        technicalDetail: 'Permission permanently denied: ${permission.toString()}',
      );
    }

    // Show rationale dialog if context is available
    if (_context != null && status.isDenied) {
      final shouldRequest = await _showPermissionRationaleDialog(
        _context,
        title,
        message,
      );

      if (!shouldRequest) {
        return false;
      }
    }

    // Request permission with timeout
    try {
      final result = await permission.request().timeout(
        AppConstants.permissionRequestTimeout,
        onTimeout: () => status, // Use cached status on timeout
      );

      // Update cache
      _permissionStatusCache[permission] = result;

      // Handle result
      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied) {
        throw PermissionException(
          code: 'PERMISSION_PERMANENTLY_DENIED',
          message: '${permission.toString()} access has been permanently denied. Please enable it in device settings.',
          technicalDetail: 'Permission permanently denied: ${permission.toString()}',
        );
      } else {
        // Permission denied but not permanently
        return false;
      }
    } catch (e) {
      if (e is PermissionException) {
        rethrow;
      }
      throw PermissionException(
        code: 'PERMISSION_REQUEST_FAILED',
        message: 'Unable to request ${permission.toString()} access',
        technicalDetail: 'Failed to request permission: $e',
      );
    }
  }

  /// Check if a permission is granted
  ///
  /// @param permission The permission to check
  /// @return Future-bool indicating if permission is granted
  Future<bool> _checkPermission(Permission permission) async {
    try {
      // Check status with a timeout for responsiveness
      final status = await permission.status.timeout(
        AppConstants.permissionRequestTimeout,
        onTimeout: () => _permissionStatusCache[permission] ?? PermissionStatus.denied,
      );

      // Update cache
      _permissionStatusCache[permission] = status;

      return status.isGranted;
    } catch (e) {
      // In case of error, assume permission is not granted
      return false;
    }
  }

  /// Show a dialog explaining why a permission is needed
  ///
  /// @param context BuildContext for showing the dialog
  /// @param title Dialog title
  /// @param message Dialog message
  /// @return Future-bool indicating if user agrees to proceed with permission request
  Future<bool> _showPermissionRationaleDialog(
      BuildContext context,
      String title,
      String message,
      ) async {
    // Check if context is still valid
    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppStrings.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppStrings.okButtonLabel),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }

  /// Show settings dialog when permission is permanently denied
  ///
  /// @param context BuildContext for showing the dialog
  /// @param permissionName Name of the permission for display
  /// @return Future-bool indicating if user opened settings
  Future<bool> showOpenSettingsDialog(
      BuildContext context,
      String permissionName,
      ) async {
    // Check if context is still valid
    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.permissionRequiredTitle),
          content: SingleChildScrollView(
            child: Text(
              '${AppStrings.permissionRequiredMessage}$permissionName. '
                  '${AppStrings.permissionSettingsDirections}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppStrings.cancelButton),
            ),
            TextButton(
              onPressed: () async {
                await openAppSettings();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(AppStrings.openSettingsButtonLabel),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }

  /// Open the app settings page
  ///
  /// @return Future-bool indicating if the settings page was successfully opened
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Clear the permission status cache
  ///
  /// Useful when the app is resumed and permissions might have changed
  void clearCache() {
    _permissionStatusCache.clear();
  }
}