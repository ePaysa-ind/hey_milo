/*
* File: lib/screens/medication_entry_screen.dart
* Description: Screen for adding or editing medication information
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/medication_model.dart';
import '../providers/medication_provider.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../services/logging_service.dart';

/// Screen for adding or editing medication information
///
/// This screen allows users to add a new medication or edit an existing one,
/// with fields for name, dosage, schedule, instructions, and other details.
class MedicationEntryScreen extends StatefulWidget {
  const MedicationEntryScreen({super.key});

  @override
  State<MedicationEntryScreen> createState() => _MedicationEntryScreenState();
}

class _MedicationEntryScreenState extends State<MedicationEntryScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();

  // Form state
  int _frequency = 1;
  final List<bool> _daysSelected = List.generate(7, (_) => true); // Default to all days
  String? _selectedColor;
  bool _isActive = true;

  // Editing state
  bool _isEditing = false;
  String? _medicationId;
  DateTime? _createdAt;

  // Loading state
  bool _isSaving = false;
  bool _isDeleting = false;

  // Colors for selection
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();

    // Check for medication to edit in the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForMedicationToEdit();
    });
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Check if a medication was passed for editing
  void _checkForMedicationToEdit() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Medication) {
      setState(() {
        _isEditing = true;
        _medicationId = args.id;
        _nameController.text = args.name;
        _dosageController.text = args.dosage;
        _instructionsController.text = args.instructions ?? '';
        _notesController.text = args.notes ?? '';
        _frequency = args.frequency;
        _selectedColor = args.color;
        _isActive = args.isActive;
        _createdAt = args.createdAt;

        // Convert days of week from strings to bool list
        _daysSelected.setAll(0, List.generate(7, (index) =>
            args.daysOfWeek.contains((index + 1).toString())
        ));
      });
    }
  }

  /// Save the medication (add or update)
  Future<void> _saveMedication() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final logService = Provider.of<LoggingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);
    final navigator = Navigator.of(context);

    // Convert days selected to strings (1-7)
    final List<String> daysOfWeek = [];
    for (int i = 0; i < _daysSelected.length; i++) {
      if (_daysSelected[i]) {
        daysOfWeek.add((i + 1).toString());
      }
    }

    // Ensure at least one day is selected
    if (daysOfWeek.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Please select at least one day of the week'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      // Create or update the medication
      final now = DateTime.now();

      if (_isEditing && _medicationId != null) {
        // Update existing medication
        final updatedMedication = Medication(
          id: _medicationId!,
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          instructions: _instructionsController.text.trim().isNotEmpty
              ? _instructionsController.text.trim()
              : null,
          frequency: _frequency,
          daysOfWeek: daysOfWeek,
          color: _selectedColor,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          isActive: _isActive,
          createdAt: _createdAt ?? now,
          updatedAt: now,
        );

        final result = await provider.updateMedication(updatedMedication);

        if (result != null && mounted) {
          navigator.pop(result);
        }
      } else {
        // Create new medication
        final newMedication = Medication(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          instructions: _instructionsController.text.trim().isNotEmpty
              ? _instructionsController.text.trim()
              : null,
          frequency: _frequency,
          daysOfWeek: daysOfWeek,
          color: _selectedColor,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          isActive: _isActive,
          createdAt: now,
          updatedAt: now,
        );

        final result = await provider.addMedication(newMedication);

        if (result != null && mounted) {
          navigator.pop(result);
        }
      }
    } catch (e, stackTrace) {
      logService.error('Failed to save medication', e, stackTrace);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not save medication: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Delete the medication
  Future<void> _deleteMedication() async {
    // Only allow deletion in edit mode
    if (!_isEditing || _medicationId == null) return;

    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final logService = Provider.of<LoggingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);
    final navigator = Navigator.of(context);
    final medicationName = _nameController.text;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Medication'),
        content: Text('Are you sure you want to delete $medicationName? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppTheme.errorColor(dialogContext),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      setState(() {
        _isDeleting = true;
      });

      final success = await provider.deleteMedication(_medicationId!);

      if (success && mounted) {
        navigator.pop();
      }
    } catch (e, stackTrace) {
      logService.error('Failed to delete medication', e, stackTrace);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not delete medication: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving && !_isDeleting,
      onPopInvokedWithResult: (didPop, result) async {
        // If already popped or currently saving/deleting, do nothing
        if (didPop || _isSaving || _isDeleting) return;

        // Store local references to avoid BuildContext usage across async gaps
        final navigator = Navigator.of(context);

        // Show confirmation dialog if form has been edited
        if (_nameController.text.isNotEmpty ||
            _dosageController.text.isNotEmpty ||
            _instructionsController.text.isNotEmpty ||
            _notesController.text.isNotEmpty) {
          showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('Discard Changes?'),
              content: Text('You have unsaved changes. Are you sure you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true); // Close dialog
                    navigator.pop(); // Navigate back
                  },
                  child: Text('Discard'),
                ),
              ],
            ),
          );
        } else {
          // No changes, just navigate back
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
          actions: [
            if (_isEditing)
              IconButton(
                icon: Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: _isDeleting || _isSaving ? null : _deleteMedication,
              ),
          ],
        ),
        body: SafeArea(
          child: _isSaving || _isDeleting
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppConstants.defaultPadding),
                Text(
                  _isSaving
                      ? 'Saving medication...'
                      : 'Deleting medication...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          )
              : SingleChildScrollView(
            padding: EdgeInsets.all(AppConstants.defaultPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medication name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Medication Name',
                      hintText: 'Enter medication name',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a medication name';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Dosage field
                  TextFormField(
                    controller: _dosageController,
                    decoration: InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g. 10mg, 1 tablet, 2 capsules',
                      prefixIcon: Icon(Icons.architecture),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the dosage';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Frequency selector
                  Text(
                    'How many times per day?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: AppConstants.defaultPadding / 2),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('Once'),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        label: Text('Twice'),
                      ),
                      ButtonSegment<int>(
                        value: 3,
                        label: Text('3x'),
                      ),
                      ButtonSegment<int>(
                        value: 4,
                        label: Text('4x'),
                      ),
                    ],
                    selected: {_frequency},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _frequency = selected.first;
                      });
                    },
                  ),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Days of week selector
                  Text(
                    'Which days?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: AppConstants.defaultPadding / 2),
                  _buildDaySelector(),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Color selection
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: AppConstants.defaultPadding / 2),
                  _buildColorSelector(),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Instructions field
                  TextFormField(
                    controller: _instructionsController,
                    decoration: InputDecoration(
                      labelText: 'Instructions (Optional)',
                      hintText: 'e.g. Take with food, take before bedtime',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 2,
                  ),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Any additional information',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),

                  SizedBox(height: AppConstants.defaultPadding),

                  // Active toggle
                  SwitchListTile(
                    title: Text(
                      'Active',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      'Receive reminders for this medication',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),

                  SizedBox(height: AppConstants.defaultPadding * 2),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchTargetSize,
                    child: ElevatedButton(
                      onPressed: _saveMedication,
                      child: Text(_isEditing ? 'Update Medication' : 'Add Medication'),
                    ),
                  ),

                  // Show delete option in edit mode
                  if (_isEditing) ...[
                    SizedBox(height: AppConstants.defaultPadding),
                    SizedBox(
                      width: double.infinity,
                      height: AppConstants.minTouchTargetSize,
                      child: OutlinedButton(
                        onPressed: _deleteMedication,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor(context),
                          side: BorderSide(
                            color: AppTheme.errorColor(context),
                          ),
                        ),
                        child: Text('Delete Medication'),
                      ),
                    ),
                  ],

                  SizedBox(height: AppConstants.defaultPadding * 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the day of week selector
  Widget _buildDaySelector() {
    final theme = Theme.of(context);
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        return InkWell(
          onTap: () {
            setState(() {
              _daysSelected[index] = !_daysSelected[index];
            });
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Container(
            width: AppConstants.minTouchTargetSize - 8,
            height: AppConstants.minTouchTargetSize - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _daysSelected[index]
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: _daysSelected[index]
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                dayLabels[index],
                style: TextStyle(
                  color: _daysSelected[index]
                      ? theme.colorScheme.onPrimary
                      : theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Build the color selector
  Widget _buildColorSelector() {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _availableColors.map((color) {
        // Convert color to string using the new non-deprecated properties
        final colorStr = '${(color.a * 255).toInt().toRadixString(16).padLeft(2, '0')}'
            '${(color.r * 255).toInt().toRadixString(16).padLeft(2, '0')}'
            '${(color.g * 255).toInt().toRadixString(16).padLeft(2, '0')}'
            '${(color.b * 255).toInt().toRadixString(16).padLeft(2, '0')}';
        final isSelected = _selectedColor == colorStr;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedColor = isSelected ? null : colorStr;
            });
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Container(
            width: AppConstants.minTouchTargetSize - 8,
            height: AppConstants.minTouchTargetSize - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
              Icons.check,
              color: theme.colorScheme.onPrimary,
            )
                : null,
          ),
        );
      }).toList(),
    );
  }
}