// Project: Milo App
// File: lib/core/injection.dart
// Purpose: Dependency injection setup using get_it
// Date: May 6, 2025

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';

import 'package:hey_milo/services/logging_service.dart';
import 'package:hey_milo/services/permission_service.dart';
import 'package:hey_milo/services/local_storage_service.dart';
import 'package:hey_milo/services/audio_service.dart';
// Uncomment needed services
import 'package:hey_milo/services/notification_service.dart';
import 'package:hey_milo/services/medication_service.dart';
//import 'package:hey_milo/services/cloud_storage_service.dart';
//import 'package:hey_milo/services/cleanup_service.dart';
//import 'package:hey_milo/services/usage_tracking_service.dart';

/// Global GetIt instance for dependency injection
final GetIt getIt = GetIt.instance;

/// Initializes all dependencies and registers them with GetIt
///
/// This method should be called once during app initialization
/// It configures all services as lazy singletons so they're only
/// instantiated when first accessed.
///
/// Throws exceptions if any service fails to register properly.
Future<void> setupDependencyInjection() async {
  try {
    // Register LoggingService first so other services can use it
    getIt.registerLazySingleton<LoggingService>(
      () => LoggingService()..initialize(enableFileLogging: !kReleaseMode),
    );

    final loggingService = getIt<LoggingService>();
    loggingService.debug('Setting up dependency injection...');

    // Register PermissionService
    getIt.registerLazySingleton<PermissionService>(() => PermissionService());

    // Register required services for the app to function

    // Register LocalStorageService - Required for RecordingsProvider
    getIt.registerLazySingleton<LocalStorageService>(
      () => LocalStorageService(),
    );

    // Register AudioService - Required for PlayerProvider and RecordingsProvider
    getIt.registerLazySingleton<AudioService>(() => AudioService());

    // Register NotificationService - No constructor parameters needed
    // The service gets its dependencies directly from GetIt
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );

    // Register MedicationService - No constructor parameters needed
    // The service gets its dependencies directly from GetIt
    getIt.registerLazySingleton<MedicationService>(() => MedicationService());

    // These can remain commented until implemented
    /*
    // Register CloudStorageService
    getIt.registerLazySingleton<CloudStorageService>(
      () => CloudStorageServiceImpl(
        loggingService: loggingService,
      ),
    );

    // Register CleanupService
    getIt.registerLazySingleton<CleanupService>(
      () => CleanupServiceImpl(
        loggingService: loggingService,
        localStorageService: getIt<LocalStorageService>(),
      ),
    );

    // Register UsageTrackingService
    getIt.registerLazySingleton<UsageTrackingService>(
      () => UsageTrackingServiceImpl(
        loggingService: loggingService,
      ),
    );
    */

    loggingService.debug('Dependency injection setup complete');
  } catch (e, stackTrace) {
    // Log the error and rethrow to be handled by the calling code
    final loggingService =
        getIt.isRegistered<LoggingService>()
              ? getIt<LoggingService>()
              : LoggingService()
          ..initialize(enableFileLogging: false);

    loggingService.error(
      'Failed to set up dependency injection',
      e,
      stackTrace,
    );

    rethrow;
  }
}

/// Resets all registered dependencies
///
/// This is primarily used for testing to ensure a clean state
/// between test runs.
Future<void> resetDependencies() async {
  await getIt.reset();
}

/// Registers mock implementations of services for testing
///
/// [mockServices] is a map of service types to their mock implementations
void registerMocks(Map<Type, dynamic> mockServices) {
  mockServices.forEach((serviceType, implementation) {
    if (getIt.isRegistered(instance: implementation)) {
      getIt.unregister(instance: implementation);
    }
    getIt.registerSingleton(implementation);
  });
}
