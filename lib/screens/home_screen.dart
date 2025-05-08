/*
* File: lib/screens/home_screen.dart
* Description: Main home screen showing primary app functions with bottom navigation
* Date: May 8, 2025
* Author: Mango App Development Team
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';

import '../config/constants.dart';
import '../providers/recordings_provider.dart';
import '../providers/player_provider.dart';
import '../providers/medication_provider.dart';
import '../providers/caregiver_messages_provider.dart';
import '../services/logging_service.dart';
import '../theme/app_theme.dart';
import '../models/caregiver_message_model.dart';
import '../screens/medication_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;

  // Default to home screen (index 4)
  const HomeScreen({super.key, this.initialTab = 4});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LoggingService? _logger;
  String? _initError;
  bool _providersAvailable = false;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _initLogging();
  }

  // Initialize logging service
  void _initLogging() {
    try {
      _logger = GetIt.instance<LoggingService>();
      _logger?.info('HomeScreen: Initializing home screen');
    } catch (e) {
      _initError = 'Logger unavailable: $e';
    }
  }

  // Safely load data from providers
  void _safeLoadData(BuildContext context) {
    try {
      if (_providersAvailable) return;

      _logger?.info('HomeScreen: Attempting to load data from providers');

      // Load recordings
      try {
        final recordingsProvider = Provider.of<RecordingsProvider?>(
          context,
          listen: false,
        );
        if (recordingsProvider != null) {
          recordingsProvider.loadMemoryEntries();
        }
      } catch (e) {
        _logger?.error('HomeScreen: Recordings provider not available: $e');
      }

      // Load medications
      try {
        final medicationProvider = Provider.of<MedicationProvider?>(
          context,
          listen: false,
        );
        if (medicationProvider != null) {
          medicationProvider.loadMedications();
        }
      } catch (e) {
        _logger?.error('HomeScreen: Medication provider not available: $e');
      }

      // Load caregiver messages
      try {
        final caregiverProvider = Provider.of<CaregiverMessagesProvider?>(
          context,
          listen: false,
        );
        if (caregiverProvider != null) {
          caregiverProvider.loadMessages();
        }
      } catch (e) {
        _logger?.error('HomeScreen: Caregiver provider not available: $e');
      }

      _providersAvailable = true;
    } catch (e) {
      _logger?.error('HomeScreen: Error loading data from providers: $e');
      _initError = 'Provider error: $e';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeLoadData(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _buildErrorScreen(_initError!);
    }

    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Error screen when initialization fails
  Widget _buildErrorScreen(String errorMessage) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hey Mango')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor(context),
              ),
              SizedBox(height: AppConstants.defaultPadding),
              const Text(
                'Application Error',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppConstants.defaultPadding / 2),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppConstants.defaultPadding),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _providersAvailable = false;
                    _initError = null;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Main content router that determines which screen to show based on tab index
  Widget _buildCurrentScreen() {
    _logger?.info('HomeScreen: Building screen for index $_currentIndex');

    switch (_currentIndex) {
      case 0:
        // FIXED: Directly show the MedicationListScreen instead of using Navigator
        return MedicationListScreen();
      case 1:
        return _buildRecordContent();
      case 2:
        return _buildCaregiverContent();
      case 3:
        return _buildRefillsPlaceholder();
      case 4:
      default:
        return _buildHomeContent();
    }
  }

  // UPDATED: Home screen content with consistent card design
  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    final contentPadding = AppConstants.defaultPadding;
    final cardSpacing = 16.0;
    final cardBorderRadius = AppTheme.borderRadius(context);

    return SafeArea(
      child: Padding(
        // Adjusted padding to prevent overflow
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spacer to push content down slightly
            const SizedBox(height: 16),

            // Expanded scrollable area to prevent overflow
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // UPDATED: Medication card - using AppTheme colors
                    _buildCard(
                      icon: Icons.medication_outlined,
                      iconColor: AppTheme.errorColor(context),
                      iconBgColor: AppTheme.errorColor(
                        context,
                      ).withValues(alpha: 51),
                      title: 'Medication Reminder',
                      description:
                          'Keep track of your medications, set reminders, and never miss a dose.',
                      onTap: () => setState(() => _currentIndex = 0),
                      borderColor: AppTheme.errorColor(context),
                      borderRadius: cardBorderRadius,
                    ),

                    SizedBox(height: cardSpacing),

                    // Card 2: Record Memories - using theme colors
                    _buildCard(
                      icon: Icons.mic,
                      iconColor: theme.colorScheme.primary,
                      iconBgColor: theme.colorScheme.primary.withValues(
                        alpha: 51,
                      ),
                      title: 'Record Memories',
                      description: 'Share with loved ones.',
                      onTap: () => setState(() => _currentIndex = 1),
                      borderColor: theme.colorScheme.primary,
                      borderRadius: cardBorderRadius,
                    ),

                    SizedBox(height: cardSpacing),

                    // Card 3: Caregiver Connect - using AppTheme
                    _buildCard(
                      icon: Icons.chat_bubble_outline,
                      iconColor: AppTheme.successColor(context),
                      iconBgColor: AppTheme.successColor(
                        context,
                      ).withValues(alpha: 51),
                      title: 'Caregiver Connect',
                      description: 'Stay in touch.',
                      onTap: () => setState(() => _currentIndex = 2),
                      borderColor: AppTheme.successColor(context),
                      borderRadius: cardBorderRadius,
                    ),

                    SizedBox(height: cardSpacing),

                    // Card 4: Scan Medication (Coming Soon) - using theme colors
                    _buildCard(
                      icon: Icons.qr_code_scanner,
                      iconColor: theme.colorScheme.secondary,
                      iconBgColor: theme.colorScheme.secondary.withValues(
                        alpha: 26,
                      ),
                      title: 'Scan Medication',
                      description:
                          'Coming soon - quickly refill prescriptions.',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scan Medication feature coming soon!',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderColor: theme.colorScheme.secondary,
                      isDisabled: true,
                      borderRadius: cardBorderRadius,
                    ),

                    // Additional padding at bottom to ensure no overflow
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Privacy message at the bottom of the screen
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: contentPadding / 2,
              ),
              child: Text(
                'All your data is stored only on your device.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Card builder with consistent design for all cards
  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color borderColor,
    double? borderRadius,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final disabledColor = theme.disabledColor;
    final actualBorderRadius = borderRadius ?? AppTheme.borderRadius(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(actualBorderRadius),
        side: BorderSide(
          color: isDisabled ? disabledColor : borderColor,
          width: 2.5,
        ),
      ),
      color: cardColor, // Use theme card color instead of hardcoded black
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(actualBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon with background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      isDisabled
                          ? disabledColor.withValues(alpha: 50)
                          : iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDisabled ? disabledColor : iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Text content - using flexible to prevent overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isDisabled
                                ? disabledColor
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDisabled
                                ? disabledColor.withValues(alpha: 0.6)
                                : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow icon (only for enabled cards)
              if (!isDisabled)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Record content with navigation button
  Widget _buildRecordContent() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 200),
            ),

            const SizedBox(height: 24),

            Text(
              'Voice Memories',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              'Record voice notes to remember important information or share memories with your caregivers.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                _logger?.info('HomeScreen: Navigating to record memory screen');
                Navigator.pushNamed(context, '/record-memory');
              },
              icon: const Icon(Icons.mic),
              label: const Text('Record a Memory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 48),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Memories', style: theme.textTheme.titleLarge),
            ),

            const SizedBox(height: 16),

            _buildMemoriesList(theme),

            const SizedBox(height: 40),

            // Replaced with simplified privacy message
            Text(
              "All your data is stored only on your device.",
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build memories list with safe provider access
  Widget _buildMemoriesList(ThemeData theme) {
    try {
      final recordingsProvider = Provider.of<RecordingsProvider?>(
        context,
        listen: true,
      );

      if (recordingsProvider == null) {
        return const Center(child: Text('Loading memories...'));
      }

      if (recordingsProvider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (recordingsProvider.memories.isEmpty) {
        return Center(
          child: Text(
            'No memories recorded yet.',
            style: theme.textTheme.bodyLarge,
          ),
        );
      }

      // Display most recent 3 recordings
      final recentMemories = recordingsProvider.memories.take(3).toList();

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentMemories.length,
        itemBuilder: (context, index) {
          final memory = recentMemories[index];
          final date = memory.timestamp;
          final duration = Duration(seconds: memory.durationSeconds);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.play_circle_filled),
              title: Text(
                'Memory ${date.month}/${date.day}/${date.year}',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
              onTap: () {
                try {
                  final playerProvider = Provider.of<PlayerProvider>(
                    context,
                    listen: false,
                  );
                  playerProvider.playMemory(memory);
                } catch (e) {
                  _logger?.error('Error playing memory: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to play memory at this time'),
                    ),
                  );
                }
              },
            ),
          );
        },
      );
    } catch (e) {
      return Center(
        child: Text(
          'Unable to load memories',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
  }

  // Caregiver content with navigation button
  Widget _buildCaregiverContent() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert,
              size: 72,
              color: AppTheme.successColor(context).withValues(alpha: 200),
            ),

            const SizedBox(height: 24),

            Text(
              'Caregiver Messages',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Text(
              'Stay connected with your caregivers through simple messaging.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                _logger?.info(
                  'HomeScreen: Navigating to caregiver messages screen',
                );
                Navigator.pushNamed(context, '/caregiver-messages');
              },
              icon: const Icon(Icons.message),
              label: const Text('View Messages'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 48),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Messages', style: theme.textTheme.titleLarge),
            ),

            const SizedBox(height: 16),

            _buildCaregiverMessagesList(theme),

            const SizedBox(height: 40),

            // Replaced with simplified privacy message
            Text(
              "All your data is stored only on your device.",
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build caregiver messages list with safe provider access
  Widget _buildCaregiverMessagesList(ThemeData theme) {
    try {
      final messagesProvider = Provider.of<CaregiverMessagesProvider?>(
        context,
        listen: true,
      );

      if (messagesProvider == null) {
        return const Center(child: Text('Loading messages...'));
      }

      if (messagesProvider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (messagesProvider.messages.isEmpty) {
        return Center(
          child: Text('No messages yet.', style: theme.textTheme.bodyLarge),
        );
      }

      // Display most recent 3 messages
      final recentMessages = messagesProvider.messages.take(3).toList();

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentMessages.length,
        itemBuilder: (context, index) {
          final message = recentMessages[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: message.isRead ? null : theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(
                message.type == CaregiverMessageType.text
                    ? Icons.message
                    : Icons.mic,
                color: message.isRead ? null : theme.colorScheme.primary,
              ),
              title: Text(
                message.sender.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight:
                      message.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                message.type == CaregiverMessageType.text
                    ? message.content.length > 30
                        ? '${message.content.substring(0, 30)}...'
                        : message.content
                    : 'Voice message',
              ),
              trailing:
                  message.isRead ? null : const Icon(Icons.circle, size: 12),
              onTap: () {
                // View message details
                Navigator.pushNamed(context, '/caregiver-messages');
              },
            ),
          );
        },
      );
    } catch (e) {
      return Center(
        child: Text(
          'Unable to load messages',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
  }

  // Placeholder for the refills screen (disabled feature)
  Widget _buildRefillsPlaceholder() {
    final theme = Theme.of(context);
    final cardBorderRadius = AppTheme.borderRadius(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_information,
              size: 72,
              color: theme.colorScheme.secondary.withValues(alpha: 180),
            ),

            const SizedBox(height: 24),

            Text(
              'Medication Refills',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(cardBorderRadius),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 100),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Coming Soon!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'This feature is currently in development. Soon, you\'ll be able to scan your medication bottles and order refills directly through the app.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentIndex = 0; // Switch to medications tab
                });
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('View My Medications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Replaced with simplified privacy message
            Text(
              "All your data is stored only on your device.",
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Bottom navigation bar with ONLY 4 buttons
  Widget _buildBottomNavigation() {
    _logger?.debug('HomeScreen: Building bottom navigation bar');

    final theme = Theme.of(context);

    // Get colors from the theme
    final medicationColor = AppTheme.errorColor(context);
    final recordColor = theme.colorScheme.primary;
    final caregiverColor = AppTheme.successColor(context);
    final refillsColor = theme.colorScheme.secondary;

    // UPDATED: using simpler bottom navigation to avoid overflow
    return BottomNavigationBar(
      currentIndex: _currentIndex > 3 ? 0 : _currentIndex,
      onTap: (index) {
        _logger?.info('HomeScreen: Navigation tab $index tapped');

        // If index 3 (Medication Refills) is tapped, show snackbar message
        if (index == 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medication Refills feature coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.scaffoldBackgroundColor,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      showUnselectedLabels: true,
      iconSize: 24,
      items: [
        BottomNavigationBarItem(
          icon: Icon(
            Icons.add_circle,
            color:
                _currentIndex == 0
                    ? medicationColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          label: 'Medications',
          backgroundColor: medicationColor,
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.mic,
            color:
                _currentIndex == 1
                    ? recordColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          label: 'Record',
          backgroundColor: recordColor,
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.swap_vert,
            color:
                _currentIndex == 2
                    ? caregiverColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          label: 'Caregiver',
          backgroundColor: caregiverColor,
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.medical_information,
            color: theme.disabledColor, // Using theme for disabled color
          ),
          label: 'Refills',
          backgroundColor: refillsColor,
        ),
      ],
    );
  }
}
