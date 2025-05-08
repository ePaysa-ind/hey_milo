/*
* File: lib/screens/medication_list_screen.dart
* Description: Screen to display user's medications and allow for marking as taken
* Date: May 8, 2025
* Author: Mango App Development Team
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/medication_model.dart';
import '../providers/medication_provider.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../services/logging_service.dart';
import 'package:get_it/get_it.dart';

/// Screen to display and manage medications
///
/// This screen displays a list of the user's medications, shows which ones
/// are due today, and allows the user to mark medications as taken.
class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen>
    with SingleTickerProviderStateMixin {
  // Tab controller for switching between today's medications and all medications
  late TabController _tabController;

  // Flag to show loading indicators during operations
  bool _isProcessing = false;

  // LoggingService
  late final LoggingService _loggingService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loggingService = GetIt.instance<LoggingService>();

    // Load medications when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load medications from the provider
  Future<void> _loadMedications() async {
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    await provider.loadMedications();
  }

  /// Mark a medication as taken
  Future<void> _markAsTaken(
    BuildContext context,
    String medicationId,
    String medicationName,
  ) async {
    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);

    try {
      setState(() {
        _isProcessing = true;
      });

      final success = await provider.markMedicationAsTaken(medicationId);

      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('$medicationName marked as taken'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed:
                  () => _undoMarkAsTaken(context, medicationId, medicationName),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.error(
        'Failed to mark medication as taken',
        e,
        stackTrace,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('ALL_DOSES_TAKEN')
                  ? 'All doses already taken for today'
                  : 'Could not mark medication as taken',
            ),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Undo marking a medication as taken
  Future<void> _undoMarkAsTaken(
    BuildContext context,
    String medicationId,
    String medicationName,
  ) async {
    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);

    try {
      setState(() {
        _isProcessing = true;
      });

      final success = await provider.undoMarkMedicationAsTaken(medicationId);

      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Undid marking $medicationName as taken'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.error(
        'Failed to undo marking medication as taken',
        e,
        stackTrace,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('NO_DOSES_TAKEN')
                  ? 'No doses taken today to undo'
                  : 'Could not undo',
            ),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Toggle a medication's active state
  Future<void> _toggleMedicationActive(
    BuildContext context,
    String medicationId,
    String medicationName,
    bool currentState,
  ) async {
    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);

    try {
      setState(() {
        _isProcessing = true;
      });

      final updatedMedication = await provider.toggleMedicationActive(
        medicationId,
      );

      if (updatedMedication != null && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              updatedMedication.isActive
                  ? '$medicationName activated'
                  : '$medicationName paused',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.error(
        'Failed to toggle medication active state',
        e,
        stackTrace,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not update medication'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Navigate to add a new medication
  void _navigateToAddMedication(BuildContext context) {
    Navigator.pushNamed(context, '/medication_entry');
  }

  /// Navigate to edit an existing medication
  void _navigateToEditMedication(BuildContext context, Medication medication) {
    Navigator.pushNamed(context, '/medication_entry', arguments: medication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: 'Due Today'), Tab(text: 'All Medications')],
        ),
      ),
      body: SafeArea(
        child: Consumer<MedicationProvider>(
          builder: (context, provider, _) {
            // Show loading indicator if provider is loading
            if (provider.isLoading || _isProcessing) {
              return Center(child: CircularProgressIndicator());
            }

            // Show error message if provider has an error
            if (provider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.errorColor(context),
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    Text(
                      'Error loading medications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: AppConstants.defaultPadding / 2),
                    Text(
                      provider.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    ElevatedButton(
                      onPressed: _loadMedications,
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // Due Today Tab
                RefreshIndicator(
                  onRefresh: _loadMedications,
                  child: _buildMedicationsList(
                    context,
                    provider.medicationsDueToday,
                    isToday: true,
                  ),
                ),

                // All Medications Tab
                RefreshIndicator(
                  onRefresh: _loadMedications,
                  child: _buildMedicationsList(
                    context,
                    provider.medications,
                    isToday: false,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddMedication(context),
        tooltip: 'Add Medication',
        child: Icon(Icons.add),
      ),
      // Only display the privacy message at the bottom
      bottomSheet: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Text(
          'All your data is stored only on your device.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build a list of medications
  Widget _buildMedicationsList(
    BuildContext context,
    List<Medication> medications, {
    required bool isToday,
  }) {
    // Show empty state if no medications
    if (medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            SizedBox(height: AppConstants.defaultPadding),
            Text(
              isToday ? 'No Medications Due Today' : 'No Medications Added',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppConstants.defaultPadding / 2),
            Text(
              isToday
                  ? 'Your medications that are due today will appear here.'
                  : 'Add your medications to receive reminders.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.defaultPadding),
            if (!isToday)
              ElevatedButton(
                onPressed: () => _navigateToAddMedication(context),
                child: Text('Add Medication'),
              ),
          ],
        ),
      );
    }

    // Display the list of medications
    return ListView.builder(
      padding: EdgeInsets.only(
        top: AppConstants.defaultPadding,
        left: AppConstants.defaultPadding,
        right: AppConstants.defaultPadding,
        // Add bottom padding to ensure content isn't covered by bottomSheet
        bottom: AppConstants.defaultPadding + 40,
      ),
      itemCount: medications.length,
      itemBuilder: (context, index) {
        final medication = medications[index];
        return _buildMedicationCard(context, medication, isToday);
      },
    );
  }

  /// Build a medication card with appropriate styling
  Widget _buildMedicationCard(
    BuildContext context,
    Medication medication,
    bool isDueToday,
  ) {
    // Determine medication color (use default if not set)
    Color medicationColor =
        medication.color != null
            ? Color(int.parse(medication.color!))
            : Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.symmetric(vertical: AppConstants.defaultPadding / 2),
      elevation: medication.isActive ? 2 : 1,
      child: InkWell(
        onTap: () => _navigateToEditMedication(context, medication),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication name and active toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Color indicator
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: medicationColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      // Medication name - with overflow handling
                      Flexible(
                        child: Text(
                          medication.name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                medication.isActive
                                    ? Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.color
                                    : Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Active toggle switch
                  Switch(
                    value: medication.isActive,
                    onChanged:
                        (value) => _toggleMedicationActive(
                          context,
                          medication.id,
                          medication.name,
                          medication.isActive,
                        ),
                  ),
                ],
              ),

              SizedBox(height: AppConstants.defaultPadding / 2),

              // Dosage information
              Row(
                children: [
                  Icon(
                    Icons.medication,
                    size: 20,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    medication.dosage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              // Frequency and schedule
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: 8),
                    // Fixed overflow by wrapping in Flexible
                    Flexible(
                      child: Text(
                        '${medication.frequency}x daily • ${_formatDaysOfWeek(medication.daysOfWeek)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Instructions if available
              if (medication.instructions != null &&
                  medication.instructions!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          medication.instructions!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: AppConstants.defaultPadding / 2),

              // "Take Now" button for medications due today
              if (isDueToday && medication.isActive)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed:
                        () => _markAsTaken(
                          context,
                          medication.id,
                          medication.name,
                        ),
                    icon: Icon(Icons.check),
                    label: Text('Take Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),

              // Inactive indicator
              if (!medication.isActive)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'PAUSED',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format days of week list for display
  String _formatDaysOfWeek(List<String> daysOfWeek) {
    if (daysOfWeek.length == 7) {
      return 'Every day';
    }

    // Sort days in calendar order (Monday first)
    final sortedDays = List<String>.from(daysOfWeek);
    sortedDays.sort();

    // Convert to day abbreviations
    final dayNames =
        sortedDays.map((day) {
          switch (day) {
            case '1':
              return 'Mon';
            case '2':
              return 'Tue';
            case '3':
              return 'Wed';
            case '4':
              return 'Thu';
            case '5':
              return 'Fri';
            case '6':
              return 'Sat';
            case '7':
              return 'Sun';
            default:
              return '';
          }
        }).toList();

    // Check for weekdays only
    if (daysOfWeek.length == 5 &&
        daysOfWeek.contains('1') &&
        daysOfWeek.contains('2') &&
        daysOfWeek.contains('3') &&
        daysOfWeek.contains('4') &&
        daysOfWeek.contains('5') &&
        !daysOfWeek.contains('6') &&
        !daysOfWeek.contains('7')) {
      return 'Weekdays';
    }

    // Check for weekends only
    if (daysOfWeek.length == 2 &&
        daysOfWeek.contains('6') &&
        daysOfWeek.contains('7') &&
        !daysOfWeek.contains('1') &&
        !daysOfWeek.contains('2') &&
        !daysOfWeek.contains('3') &&
        !daysOfWeek.contains('4') &&
        !daysOfWeek.contains('5')) {
      return 'Weekends';
    }

    // Return comma-separated list
    return dayNames.join(', ');
  }
}
