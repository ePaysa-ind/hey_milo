// file path: /hey_milo/main.dart
// Project: Milo App
// File: main.dart
// Purpose: Application entry point and initialization
// Date: May 4, 2025

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'package:hey_milo/core/injection.dart';
import 'package:hey_milo/services/logging_service.dart';
// Commented out imports for files we haven't created yet
// import 'package:hey_milo/screens/home_screen.dart';
// import 'package:hey_milo/theme/app_theme.dart';
// import 'package:hey_milo/providers/app_state_provider.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global logger instance for use in parts of the code
/// where dependency injection is not available
final Logger logger = Logger();

/// Application entry point
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Setup error handling for uncaught errors
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e('Uncaught Flutter error', error: details.exception, stackTrace: details.stack);
  };

  // Handle uncaught async errors
  // Updated from PlatformDispatcher to WidgetsBinding for compatibility
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    logger.e('Uncaught platform error', error: error, stackTrace: stack);
    return true;
  };

  // Run the app wrapped in a zone for error handling
  runZonedGuarded(
        () async {
      try {
        // Initialize dependency injection
        await setupDependencyInjection();

        // Initialize LoggingService
        final loggingService = getIt<LoggingService>();
        await loggingService.initialize();

        logger.i('Application starting...');

        // Use the HeyMilo class instead of inline MaterialApp
        runApp(const HeyMilo());

        // Original code with Riverpod (commented out until we add those dependencies)
        /*
        runApp(
          const ProviderScope(
            child: MiloApp(),
          ),
        );
        */
      } catch (e, stackTrace) {
        logger.e('Failed to initialize app', error: e, stackTrace: stackTrace);
        // Show a user-friendly error screen if initialization fails
        runApp(ErrorApp(error: e.toString()));
      }
    },
        (error, stackTrace) {
      logger.e('Uncaught error in app zone', error: error, stackTrace: stackTrace);
    },
  );
}

/// Main application widget
class HeyMilo extends StatelessWidget {
  /// Creates a new instance of [HeyMilo]
  const HeyMilo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hey Milo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text('Milo App - Initial Setup Complete'),
        ),
      ),
    );
  }
}

/*
// Commented out until we implement Riverpod and other components
class MiloApp extends ConsumerWidget {
  const MiloApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateProvider = ref.watch(appStateNotifierProvider);

    return MaterialApp(
      title: 'Milo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Respect system theme settings
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      builder: (context, child) {
        // Apply text scaling for accessibility
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
          ),
          child: child!,
        );
      },
    );
  }
}
*/

/// Error screen displayed when app initialization fails
class ErrorApp extends StatelessWidget {
  /// The error message to display
  final String error;

  /// Creates a new instance of [ErrorApp]
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sorry, something went wrong',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please restart the app and try again.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}