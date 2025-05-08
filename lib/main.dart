// Project: Milo App
// File: main.dart
// Purpose: Application entry point with optimized loading and enhanced error handling
// Date: May 7, 2025

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';

import 'package:hey_milo/core/injection.dart';
import 'package:hey_milo/services/logging_service.dart';
import 'package:hey_milo/services/audio_service.dart';
import 'package:hey_milo/services/local_storage_service.dart';
import 'package:hey_milo/services/notification_service.dart';
import 'package:hey_milo/services/medication_service.dart';
import 'package:hey_milo/theme/app_theme.dart';

// Import screens
import 'package:hey_milo/screens/home_screen.dart';
import 'package:hey_milo/screens/record_memory_screen.dart';
import 'package:hey_milo/screens/medication_entry_screen.dart';
import 'package:hey_milo/screens/medication_list_screen.dart';
import 'package:hey_milo/screens/caregiver_messages_screen.dart';

// Import providers
import 'package:hey_milo/providers/recordings_provider.dart';
import 'package:hey_milo/providers/player_provider.dart';
import 'package:hey_milo/providers/caregiver_messages_provider.dart';
import 'package:hey_milo/providers/medication_provider.dart';
import 'package:hey_milo/providers/app_state_provider.dart';

// Global initialization state tracking
bool _isInitialized = false;
final _initCompleter = Completer<void>();

// Simple logger for startup (before DI)
final Logger _startupLogger = Logger();

/// Application entry point - optimized for faster startup
void main() async {
  // Immediately pre-warm Flutter engine to reduce initialization time
  WidgetsFlutterBinding.ensureInitialized();
  _startupLogger.i('🔍 Flutter bindings initialized');

  // Set up comprehensive error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    _startupLogger.e(
      '❌ Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Handle errors that aren't caught by FlutterError
  PlatformDispatcher.instance.onError = (error, stack) {
    _startupLogger.e(
      '❌ Platform dispatcher error',
      error: error,
      stackTrace: stack,
    );
    return true; // Prevents error from propagating
  };

  _startupLogger.i('🔍 App starting...');

  // Optimize UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations immediately
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  _startupLogger.i('🔍 Device orientation set');

  // Start dependency injection in parallel with app launch
  _startupLogger.i('🔍 Starting initialization process');

  // Launch the app immediately
  runApp(const FastLoadApp());

  // Start services initialization in background
  _initializeInBackground();
}

/// Fast loading app shell that shows while services initialize
class FastLoadApp extends StatelessWidget {
  const FastLoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Initializes all services in the background
void _initializeInBackground() {
  Future.microtask(() async {
    try {
      // Step 1: Initialize dependency injection
      await setupDependencyInjection();
      _startupLogger.i('✅ Dependency injection complete');

      // Step 2: Initialize additional services
      await _initializeAdditionalServices();
      _startupLogger.i('✅ Service initialization complete');

      // Step 3: Signal initialization completion
      _isInitialized = true;
      _initCompleter.complete();

      // Step 4: Launch main app
      runApp(const HeyMilo());
    } catch (error, stackTrace) {
      _startupLogger.e(
        '❌ Initialization error',
        error: error,
        stackTrace: stackTrace,
      );
      _initCompleter.completeError(error, stackTrace);

      // Show error app if initialization fails
      runApp(ErrorApp(error: 'Initialization Error: ${error.toString()}'));
    }
  });
}

/// Initializes additional services in parallel
Future<void> _initializeAdditionalServices() async {
  try {
    _startupLogger.i('🔍 Additional service initialization started');

    // Run initializations in parallel for faster startup
    final futures = <Future>[];

    // Initialize LocalStorageService
    try {
      final localStorageService = GetIt.instance<LocalStorageService>();
      futures.add(localStorageService.initialize());
    } catch (e) {
      _startupLogger.e('❌ LocalStorageService initialization failed: $e');
    }

    // Initialize MedicationService
    try {
      final medicationService = GetIt.instance<MedicationService>();
      futures.add(medicationService.initialize());
    } catch (e) {
      _startupLogger.e('❌ MedicationService initialization failed: $e');
    }

    // Initialize NotificationService
    try {
      final notificationService = GetIt.instance<NotificationService>();
      futures.add(notificationService.initialize());
    } catch (e) {
      _startupLogger.e('❌ NotificationService initialization failed: $e');
    }

    // Wait for all initializations to complete
    await Future.wait(futures);

    _startupLogger.i('🔍 Additional service initialization finished');
    return;
  } catch (e, stackTrace) {
    _startupLogger.e(
      '❌ Additional service initialization failed',
      error: e,
      stackTrace: stackTrace,
    );
    throw Exception('Failed to initialize additional services: $e');
  }
}

/// Wait for app initialization to complete
Future<void> waitForInitialization() {
  if (_isInitialized) {
    _startupLogger.i('🔍 App already initialized, returning immediately');
    return Future.value();
  }
  _startupLogger.i('🔍 Waiting for initialization to complete');
  return _initCompleter.future;
}

/// Main application widget with providers and routing
class HeyMilo extends StatefulWidget {
  const HeyMilo({super.key});

  @override
  State<HeyMilo> createState() => _HeyMiloState();
}

class _HeyMiloState extends State<HeyMilo> with WidgetsBindingObserver {
  // Providers
  AppStateProvider? _appStateProvider;
  RecordingsProvider? _recordingsProvider;
  PlayerProvider? _playerProvider;
  CaregiverMessagesProvider? _caregiverMessagesProvider;
  MedicationProvider? _medicationProvider;
  LoggingService? _loggingService;

  // State flags
  bool _providersInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _startupLogger.i('✅ HeyMilo initState called');
    WidgetsBinding.instance.addObserver(this);

    // Create providers with minimal delay
    _createProviders();
  }

  // Create providers as quickly as possible
  Future<void> _createProviders() async {
    try {
      final loggingService = GetIt.instance<LoggingService>();
      _loggingService = loggingService; // Store for provider

      final localStorageService = GetIt.instance<LocalStorageService>();

      // Create AppStateProvider first (for theme)
      _appStateProvider = AppStateProvider(
        localStorageService: localStorageService,
        loggingService: loggingService,
      );

      // Wait briefly to allow UI to render
      await Future.delayed(const Duration(milliseconds: 10));

      // Create remaining providers
      final audioService = GetIt.instance<AudioService>();
      final notificationService = GetIt.instance<NotificationService>();
      final medicationService = GetIt.instance<MedicationService>();

      // Create all providers at once
      _recordingsProvider = RecordingsProvider(
        loggingService: loggingService,
        audioService: audioService,
        localStorageService: localStorageService,
      );

      _playerProvider = PlayerProvider(
        loggingService: loggingService,
        audioService: audioService,
      );

      _caregiverMessagesProvider = CaregiverMessagesProvider(
        loggingService: loggingService,
        localStorageService: localStorageService,
      );

      _medicationProvider = MedicationProvider(
        loggingService: loggingService,
        medicationService: medicationService,
        notificationService: notificationService,
      );

      if (mounted) {
        setState(() {
          _providersInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      _startupLogger.e(
        '❌ Failed to initialize providers',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Measure frame rendering time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupLogger.i('✅ First frame of main app rendered completely');
    });
  }

  @override
  void dispose() {
    _startupLogger.i('HeyMilo widget disposed');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _startupLogger.i('📱 App lifecycle state changed to: $state');

    // If app is resumed, refresh data
    if (state == AppLifecycleState.resumed) {
      _refreshAppData();
    }
  }

  // Refresh app data when returning to the app
  void _refreshAppData() {
    if (_providersInitialized) {
      try {
        _startupLogger.i('Refreshing app data after resume');

        // Reload data from providers
        _recordingsProvider?.loadMemoryEntries();
        _medicationProvider?.loadMedications();
        _caregiverMessagesProvider?.loadMessages();
      } catch (e) {
        _startupLogger.e('Failed to refresh app data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if initialization failed
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_initError',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Text('Close App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Initial app with minimal providers
    if (!_providersInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Full app with all providers
    return MultiProvider(
      providers: [
        // Include all initialized providers
        if (_appStateProvider != null)
          ChangeNotifierProvider<AppStateProvider>.value(
            value: _appStateProvider!,
          ),
        if (_recordingsProvider != null)
          ChangeNotifierProvider<RecordingsProvider>.value(
            value: _recordingsProvider!,
          ),
        if (_playerProvider != null)
          ChangeNotifierProvider<PlayerProvider>.value(value: _playerProvider!),
        if (_caregiverMessagesProvider != null)
          ChangeNotifierProvider<CaregiverMessagesProvider>.value(
            value: _caregiverMessagesProvider!,
          ),
        if (_medicationProvider != null)
          ChangeNotifierProvider<MedicationProvider>.value(
            value: _medicationProvider!,
          ),
        // Add LoggingService to provider tree to fix error
        if (_loggingService != null)
          Provider<LoggingService>.value(value: _loggingService!),
      ],
      child: MaterialApp(
        title: 'Hey Milo',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/':
              (context) =>
                  const HomeScreen(initialTab: 4), // Start with medications tab
          '/record-memory': (context) => const RecordMemoryScreen(),
          '/medications': (context) => const MedicationListScreen(),
          '/medication_entry': (context) => const MedicationEntryScreen(),
          '/caregiver-messages': (context) => const CaregiverMessagesScreen(),
        },
      ),
    );
  }
}

/// Error screen displayed when app initialization fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    _startupLogger.e('❌ Building error UI: $error');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Sorry, something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $error',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Please restart the app and try again.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      SystemNavigator.pop(); // Exit the app
                    },
                    child: const Text('Close App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
