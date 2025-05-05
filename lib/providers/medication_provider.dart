/*
* File: lib/providers/medication_provider.dart
* Description: Provider for managing medication data and reminders
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/medication_model.dart';
import '../services/logging_service.dart';
import '../services/medication_service.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';
import '../config/constants.dart';

/// Manages medication data and reminder state for the medication tracking feature.
///
/// This provider handles:
/// - Accessing and updating medication records
/// - Scheduling and managing medication reminders
/// - Tracking medication adherence
/// - Marking medications as taken
class MedicationProvider with ChangeNotifier {
  final MedicationService _medicationService;
  final NotificationService _notificationService;
  final LoggingService _loggingService;

  // Medication state
  List<Medication> _medications = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Reminder tracking
  final Map<String, List<DateTime>> _takenMedications = {};

  /// Constructs a MedicationProvider with required services.
  MedicationProvider({
    required MedicationService medicationService,
    required NotificationService notificationService,
    required LoggingService loggingService,
  }) :
        _medicationService = medicationService,
        _notificationService = notificationService,
        _loggingService = loggingService {
    // Load existing medications when provider is initialized
    loadMedications();
  }

  /// All available medications.
  List<Medication> get medications => _medications;

  /// Whether medications are currently being loaded.
  bool get isLoading => _isLoading;

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  /// Returns medications that are due today.
  List<Medication> get medicationsDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _medications.where((medication) {
      // Check if medication is active
      if (!medication.isActive) return false;

      // Check if today is a scheduled day
      final isScheduledDay = _isDayScheduled(medication, today);
      if (!isScheduledDay) return false;

      // Check if all doses are already taken
      final takenDoses = _getTimesForDate(medication.id, today);
      return takenDoses.length < medication.frequency;
    }).toList();
  }

  /// Returns medications due within the next hour.
  List<Medication> get medicationsDueSoon {
    final now = DateTime.now();
    final nextHour = now.add(const Duration(hours: 1));

    return medicationsDueToday.where((medication) {
      // Get next dose time
      final nextDoseTime = _getNextDoseTime(medication);

      // Check if next dose is within the next hour
      return nextDoseTime != null &&
          nextDoseTime.isAfter(now) &&
          nextDoseTime.isBefore(nextHour);
    }).toList();
  }

  /// Loads all existing medications from storage.
  Future<void> loadMedications() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load medications data
      final medicationsData = await _medicationService.getMedications();
      _medications = medicationsData;

      // Load taken medication history
      await _loadTakenMedicationsHistory();

      // Reschedule notifications for all active medications
      _scheduleNotificationsForAllMedications();
    } catch (e, stackTrace) {
      _handleError('Failed to load medications', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new medication and schedules its reminders.
  ///
  /// Returns the added Medication if successful, null otherwise.
  Future<Medication?> addMedication(Medication medication) async {
    try {
      _errorMessage = null;

      // Add the medication
      final addedMedication = await _medicationService.addMedication(medication);

      // Add to the local list
      _medications.add(addedMedication);

      // Schedule notifications if the medication is active
      if (addedMedication.isActive) {
        await _scheduleNotificationsForMedication(addedMedication);
      }

      notifyListeners();
      return addedMedication;
    } catch (e, stackTrace) {
      _handleError('Failed to add medication', e, stackTrace);
      return null;
    }
  }

  /// Updates an existing medication and reschedules its reminders if needed.
  ///
  /// Returns the updated Medication if successful, null otherwise.
  Future<Medication?> updateMedication(Medication medication) async {
    try {
      _errorMessage = null;

      // Find the medication index
      final index = _medications.indexWhere((med) => med.id == medication.id);
      if (index == -1) {
        throw MiloException(
            code: 'MEDICATION_NOT_FOUND',
            message: 'The medication you are trying to update does not exist.'
        );
      }

      // Update the medication
      final updatedMedication = await _medicationService.updateMedication(medication);

      // Update the local list
      _medications[index] = updatedMedication;

      // Cancel existing notifications for this medication
      await _cancelNotificationsForMedication(medication.id);

      // Schedule new notifications if the medication is active
      if (updatedMedication.isActive) {
        await _scheduleNotificationsForMedication(updatedMedication);
      }

      notifyListeners();
      return updatedMedication;
    } catch (e, stackTrace) {
      _handleError('Failed to update medication', e, stackTrace);
      return null;
    }
  }

  /// Deletes a medication and cancels its reminders.
  ///
  /// Returns true if deletion was successful, false otherwise.
  Future<bool> deleteMedication(String medicationId) async {
    try {
      _errorMessage = null;

      // Find the medication index
      final index = _medications.indexWhere((med) => med.id == medicationId);
      if (index == -1) {
        throw MiloException(
            code: 'MEDICATION_NOT_FOUND',
            message: 'The medication you are trying to delete does not exist.'
        );
      }

      // Delete the medication
      await _medicationService.deleteMedication(medicationId);

      // Remove from the local list
      _medications.removeAt(index);

      // Cancel notifications for this medication
      await _cancelNotificationsForMedication(medicationId);

      // Remove from taken medications history
      _takenMedications.remove(medicationId);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to delete medication', e, stackTrace);
      return false;
    }
  }

  /// Toggles the active state of a medication.
  ///
  /// Returns the updated Medication if successful, null otherwise.
  Future<Medication?> toggleMedicationActive(String medicationId) async {
    try {
      _errorMessage = null;

      // Find the medication
      final index = _medications.indexWhere((med) => med.id == medicationId);
      if (index == -1) {
        throw MiloException(
            code: 'MEDICATION_NOT_FOUND',
            message: 'The medication you are trying to update does not exist.'
        );
      }

      // Toggle active state
      final medication = _medications[index];
      final updatedMedication = medication.copyWith(
          isActive: !medication.isActive
      );

      // Update the medication
      return updateMedication(updatedMedication);
    } catch (e, stackTrace) {
      _handleError('Failed to toggle medication active state', e, stackTrace);
      return null;
    }
  }

  /// Marks a medication as taken at the current time.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> markMedicationAsTaken(String medicationId) async {
    try {
      _errorMessage = null;

      // Find the medication
      final medication = _medications.firstWhere(
              (med) => med.id == medicationId,
          orElse: () => throw MiloException(
              code: 'MEDICATION_NOT_FOUND',
              message: 'The medication you are trying to mark as taken does not exist.'
          )
      );

      // Get the current date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get the list of times this medication was taken today
      final takenToday = _getTimesForDate(medicationId, today);

      // Check if all doses for today have already been taken
      if (takenToday.length >= medication.frequency) {
        throw MiloException(
            code: 'ALL_DOSES_TAKEN',
            message: 'You have already taken all doses of this medication for today.'
        );
      }

      // Add the current time to the taken list
      if (!_takenMedications.containsKey(medicationId)) {
        _takenMedications[medicationId] = [];
      }
      _takenMedications[medicationId]!.add(now);

      // Save the updated history
      await _saveTakenMedicationsHistory();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to mark medication as taken', e, stackTrace);
      return false;
    }
  }

  /// Undoes marking a medication as taken (removes the last taken record for today).
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> undoMarkMedicationAsTaken(String medicationId) async {
    try {
      _errorMessage = null;

      // Get the current date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get the list of times this medication was taken today
      final takenToday = _getTimesForDate(medicationId, today);

      // Check if there are any doses taken today
      if (takenToday.isEmpty) {
        throw MiloException(
            code: 'NO_DOSES_TAKEN',
            message: 'No doses of this medication have been taken today.'
        );
      }

      // Remove the last taken time for today
      takenToday.sort((a, b) => b.compareTo(a)); // Sort in descending order
      final lastTakenTime = takenToday[0];

      _takenMedications[medicationId]!.remove(lastTakenTime);

      // Save the updated history
      await _saveTakenMedicationsHistory();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to undo marking medication as taken', e, stackTrace);
      return false;
    }
  }

  /// Returns the list of times a medication was taken on a specific date.
  List<DateTime> _getTimesForDate(String medicationId, DateTime date) {
    if (!_takenMedications.containsKey(medicationId)) {
      return [];
    }

    return _takenMedications[medicationId]!.where((takenTime) {
      return takenTime.year == date.year &&
          takenTime.month == date.month &&
          takenTime.day == date.day;
    }).toList();
  }

  /// Calculates the next dose time for a medication.
  DateTime? _getNextDoseTime(Medication medication) {
    if (!medication.isActive) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if today is a scheduled day
    if (!_isDayScheduled(medication, today)) return null;

    // Get the list of times this medication was taken today
    final takenToday = _getTimesForDate(medication.id, today);

    // Check if all doses for today have already been taken
    if (takenToday.length >= medication.frequency) return null;

    // Calculate time intervals based on frequency
    final awakePeriod = 14; // Assume 14 hours awake (e.g., 8am to 10pm)
    final intervalHours = awakePeriod / medication.frequency;

    // Get start time (e.g., 8am)
    final startHour = 8; // 8am
    final startTime = DateTime(
      today.year,
      today.month,
      today.day,
      startHour,
    );

    // Calculate all dose times for today
    final List<DateTime> doseTimes = [];
    for (var i = 0; i < medication.frequency; i++) {
      final doseTime = startTime.add(Duration(
        hours: (intervalHours * i).floor(),
        minutes: ((intervalHours * i) % 1 * 60).floor(),
      ));
      doseTimes.add(doseTime);
    }

    // Find the next dose that hasn't been taken
    for (final doseTime in doseTimes) {
      // Check if this dose time has already been taken
      bool isDoseTaken = false;
      for (final takenTime in takenToday) {
        // Consider a dose "taken" if a taken record exists within 30 minutes of the dose time
        if ((takenTime.difference(doseTime).inMinutes).abs() < 30) {
          isDoseTaken = true;
          break;
        }
      }

      if (!isDoseTaken && doseTime.isAfter(now)) {
        return doseTime;
      }
    }

    // If all doses are either taken or in the past, return null
    return null;
  }

  /// Checks if a medication is scheduled for a specific day.
  bool _isDayScheduled(Medication medication, DateTime date) {
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday

    return medication.daysOfWeek.contains(dayOfWeek.toString());
  }

  /// Schedules notifications for all active medications.
  Future<void> _scheduleNotificationsForAllMedications() async {
    try {
      // Cancel all existing medication notifications
      await _notificationService.cancelAllMedicationReminders();

      // Schedule notifications for each active medication
      for (final medication in _medications) {
        if (medication.isActive) {
          await _scheduleNotificationsForMedication(medication);
        }
      }
    } catch (e, stackTrace) {
      _loggingService.error(
          'Failed to schedule notifications for all medications',
          e,
          stackTrace
      );
    }
  }

  /// Schedules notifications for a specific medication.
  Future<void> _scheduleNotificationsForMedication(Medication medication) async {
    try {
      // Skip if medication is not active
      if (!medication.isActive) return;

      // Calculate dose times for the next 7 days
      final now = DateTime.now();

      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final date = now.add(Duration(days: dayOffset));
        final dateOnly = DateTime(date.year, date.month, date.day);

        // Skip if this day is not scheduled
        if (!_isDayScheduled(medication, dateOnly)) continue;

        // Calculate time intervals based on frequency
        final awakePeriod = 14; // Assume 14 hours awake (e.g., 8am to 10pm)
        final intervalHours = awakePeriod / medication.frequency;

        // Get start time (e.g., 8am)
        final startHour = 8; // 8am
        final startTime = DateTime(
          dateOnly.year,
          dateOnly.month,
          dateOnly.day,
          startHour,
        );

        // Schedule notifications for each dose
        for (var i = 0; i < medication.frequency; i++) {
          final doseTime = startTime.add(Duration(
            hours: (intervalHours * i).floor(),
            minutes: ((intervalHours * i) % 1 * 60).floor(),
          ));

          // Skip if this dose time is in the past
          if (doseTime.isBefore(now)) continue;

          // Schedule the notification
          final notificationId = '${medication.id}_${DateUtils.formatDateTimeForId(doseTime)}';
          final title = 'Time to take ${medication.name}';
          final body = 'Dosage: ${medication.dosage} • Tap to mark as taken';

          await _notificationService.scheduleMedicationReminder(
            id: notificationId,
            title: title,
            body: body,
            scheduledTime: doseTime,
            medicationId: medication.id,
            channelId: AppConstants.medicationChannelId,
            channelName: AppConstants.medicationChannelName,
            channelDescription: AppConstants.medicationChannelDescription,
          );
        }
      }
    } catch (e, stackTrace) {
      _loggingService.error(
          'Failed to schedule notifications for medication: ${medication.id}',
          e,
          stackTrace
      );
    }
  }

  /// Cancels all notifications for a specific medication.
  Future<void> _cancelNotificationsForMedication(String medicationId) async {
    try {
      await _notificationService.cancelMedicationReminders(medicationId);
    } catch (e, stackTrace) {
      _loggingService.error(
          'Failed to cancel notifications for medication: $medicationId',
          e,
          stackTrace
      );
    }
  }

  /// Loads the taken medications history from storage.
  Future<void> _loadTakenMedicationsHistory() async {
    try {
      final history = await _medicationService.getTakenMedicationsHistory();

      _takenMedications.clear();
      for (final entry in history.entries) {
        final medicationId = entry.key;
        final timestamps = entry.value.map((ts) => DateTime.parse(ts)).toList();
        _takenMedications[medicationId] = timestamps;
      }
    } catch (e, stackTrace) {
      _loggingService.error(
          'Failed to load taken medications history',
          e,
          stackTrace
      );
    }
  }

  /// Saves the taken medications history to storage.
  Future<void> _saveTakenMedicationsHistory() async {
    try {
      final history = <String, List<String>>{};

      for (final entry in _takenMedications.entries) {
        final medicationId = entry.key;
        final timestamps = entry.value.map((dt) => dt.toIso8601String()).toList();
        history[medicationId] = timestamps;
      }

      await _medicationService.saveTakenMedicationsHistory(history);
    } catch (e, stackTrace) {
      _loggingService.error(
          'Failed to save taken medications history',
          e,
          stackTrace
      );
    }
  }

  /// Handles errors by logging them and updating error state.
  void _handleError(String message, Object error, StackTrace stackTrace) {
    if (error is MiloException) {
      _errorMessage = error.message;
    } else {
      _errorMessage = message;
    }

    _loggingService.error(message, error, stackTrace);
  }
}