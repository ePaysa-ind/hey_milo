/*
* File: lib/services/medication_service.dart
* Description: Medication Service for managing medication data and reminders in the Milo App
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/medication_model.dart';
import '../core/exceptions.dart';
import '../services/logging_service.dart';
import 'package:get_it/get_it.dart';

/// Service responsible for managing medication reminders.
class MedicationService {
  final LoggingService _logger = GetIt.instance<LoggingService>();

  static const String _tableName = 'medications';
  static const String _tableReminders = 'medication_reminders';
  static const String _tableTakenHistory = 'medication_taken_history';

  late sqflite.Database _database;
  bool _isInitialized = false;

  final StreamController<List<Medication>> _medicationsStreamController =
  StreamController<List<Medication>>.broadcast();

  Stream<List<Medication>> get medicationsStream =>
      _medicationsStreamController.stream;

  /// Initializes the medication database.
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _logger.info('Initializing medication database');

      final databasePath = await sqflite.getDatabasesPath();
      final dbPath = join(databasePath, 'medications.db');

      _database = await sqflite.openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL,
              instructions TEXT,
              frequency INTEGER NOT NULL DEFAULT 1,
              days_of_week TEXT NOT NULL,
              color TEXT,
              notes TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE $_tableReminders (
              id TEXT PRIMARY KEY,
              medication_id TEXT NOT NULL,
              time TEXT NOT NULL,
              days TEXT NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (medication_id) REFERENCES $_tableName (id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE $_tableTakenHistory (
              id TEXT PRIMARY KEY,
              medication_id TEXT NOT NULL,
              taken_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (medication_id) REFERENCES $_tableName (id) ON DELETE CASCADE
            )
          ''');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );

      _isInitialized = true;
      _logger.info('Medication DB initialized');
      await _refreshMedicationsStream();
    } catch (e, stackTrace) {
      _logger.error('DB init error: $e');
      throw DatabaseException.initFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Adds a new medication to the database.
  ///
  /// Returns the added medication with created and updated timestamps.
  Future<Medication> addMedication(Medication medication) async {
    try {
      _ensureInitialized();
      final now = DateTime.now();

      final updated = medication.copyWithTimestamps(
        createdAt: medication.createdAt,
        updatedAt: now,
      );

      await _database.insert(
        _tableName,
        updated.toJson(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      await _refreshMedicationsStream();
      return updated;
    } catch (e, stackTrace) {
      _logger.error('Create med error: $e');
      throw DatabaseException.insertFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Updates an existing medication in the database.
  ///
  /// Returns the updated medication with updated timestamp.
  Future<Medication> updateMedication(Medication medication) async {
    try {
      _ensureInitialized();

      if (medication.id.isEmpty) {
        throw DatabaseException(
          code: 'DB_INVALID_ID',
          message: 'Cannot update medication without ID',
          technicalDetail: 'Empty ID provided for medication update',
        );
      }

      final updated = medication.copyWithTimestamps(
        updatedAt: DateTime.now(),
      );

      await _database.update(
        _tableName,
        updated.toJson(),
        where: 'id = ?',
        whereArgs: [medication.id],
      );

      await _refreshMedicationsStream();
      return updated;
    } catch (e, stackTrace) {
      _logger.error('Update med error: $e');
      throw DatabaseException.updateFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes a medication from the database.
  Future<void> deleteMedication(String id) async {
    try {
      _ensureInitialized();

      await _database.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      await _refreshMedicationsStream();
    } catch (e, stackTrace) {
      _logger.error('Delete med error: $e');
      throw DatabaseException.deleteFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets all medications from the database.
  Future<List<Medication>> getMedications() async {
    try {
      _ensureInitialized();

      final result = await _database.query(_tableName, orderBy: 'name ASC');
      return result.map((m) => Medication.fromJson(m)).toList();
    } catch (e, stackTrace) {
      _logger.error('Fetch meds error: $e');
      throw DatabaseException.queryFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets a medication by its ID.
  Future<Medication?> getMedicationById(String id) async {
    try {
      _ensureInitialized();

      final result = await _database.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      return result.isNotEmpty ? Medication.fromJson(result.first) : null;
    } catch (e, stackTrace) {
      _logger.error('Fetch med by ID error: $e');
      throw DatabaseException.queryFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets all active medications.
  Future<List<Medication>> getActiveMedications() async {
    try {
      _ensureInitialized();

      final result = await _database.query(
        _tableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      return result.map((m) => Medication.fromJson(m)).toList();
    } catch (e, stackTrace) {
      _logger.error('Fetch active meds error: $e');
      throw DatabaseException.queryFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets medication history (when medications were taken).
  Future<Map<String, List<String>>> getTakenMedicationsHistory() async {
    try {
      _ensureInitialized();

      final Map<String, List<String>> result = {};

      final records = await _database.query(_tableTakenHistory);

      for (final record in records) {
        final medicationId = record['medication_id'] as String;
        final takenAt = record['taken_at'] as String;

        if (!result.containsKey(medicationId)) {
          result[medicationId] = [];
        }

        result[medicationId]!.add(takenAt);
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Fetch medication history error: $e');
      throw DatabaseException.queryFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Saves medication history (when medications were taken).
  Future<void> saveTakenMedicationsHistory(Map<String, List<String>> history) async {
    try {
      _ensureInitialized();

      // Start a transaction
      await _database.transaction((txn) async {
        // Clear existing history
        await txn.delete(_tableTakenHistory);

        // Insert new history
        for (final entry in history.entries) {
          final medicationId = entry.key;
          final timestamps = entry.value;

          for (final timestamp in timestamps) {
            await txn.insert(
              _tableTakenHistory,
              {
                'id': '$medicationId-$timestamp',
                'medication_id': medicationId,
                'taken_at': timestamp,
                'created_at': DateTime.now().toIso8601String(),
              },
            );
          }
        }
      });
    } catch (e, stackTrace) {
      _logger.error('Save medication history error: $e');
      throw DatabaseException.insertFailed(
        technicalDetail: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Refreshes the medications stream with latest data.
  Future<void> _refreshMedicationsStream() async {
    try {
      final meds = await getMedications();
      _medicationsStreamController.add(meds);
    } catch (e) {
      _logger.error('Refresh stream error: $e');
    }
  }

  /// Ensures the database is initialized before operations.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw DatabaseException(
        code: 'DB_NOT_INITIALIZED',
        message: 'Database not initialized',
        technicalDetail: 'Attempted to access DB before init',
      );
    }
  }

  /// Disposes resources used by the service.
  Future<void> dispose() async {
    try {
      if (_isInitialized) {
        await _database.close();
        await _medicationsStreamController.close();
        _isInitialized = false;
      }
    } catch (e) {
      _logger.error('Dispose error: $e');
    }
  }
}