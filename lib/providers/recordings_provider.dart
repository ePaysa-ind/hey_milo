import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/exceptions.dart';
import '../models/memory_model.dart';
import '../services/audio_service.dart';
import '../services/local_storage_service.dart';
import '../services/logging_service.dart';

/// Manages voice recording state and operations for memory journaling.
///
/// This provider handles the lifecycle of audio recordings, including:
/// - Recording audio memories
/// - Saving recordings with metadata
/// - Loading existing recordings
/// - Deleting recordings
/// - Managing recording state (recording, idle, etc.)
class RecordingsProvider with ChangeNotifier {
  final AudioService _audioService;
  final LocalStorageService _localStorageService;
  final LoggingService _loggingService;

  // Current recording state
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Memory entries
  List<Memory> _memories = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// Constructs a RecordingsProvider with required services.
  RecordingsProvider({
    required AudioService audioService,
    required LocalStorageService localStorageService,
    required LoggingService loggingService,
  }) :
        _audioService = audioService,
        _localStorageService = localStorageService,
        _loggingService = loggingService {
    // Load existing memory entries when provider is initialized
    loadMemoryEntries();
  }

  /// Whether audio is currently being recorded.
  bool get isRecording => _isRecording;

  /// Path to the current recording, if any.
  String? get currentRecordingPath => _currentRecordingPath;

  /// Start time of the current recording, if any.
  DateTime? get recordingStartTime => _recordingStartTime;

  /// All available memory entries.
  List<Memory> get memories => _memories;

  /// Whether memory entries are currently being loaded.
  bool get isLoading => _isLoading;

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  /// Starts recording a new memory entry.
  ///
  /// Returns true if recording started successfully, false otherwise.
  Future<bool> startRecording() async {
    if (_isRecording) {
      _loggingService.warning('Attempted to start recording while already recording');
      return false;
    }

    try {
      _errorMessage = null;

      // Generate a unique filename using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'memory_$timestamp.m4a';

      // Initialize storage service if needed
      await _localStorageService.initialize();

      // Create a temp file path for the recording
      final tempDir = await getApplicationDocumentsDirectory();
      final recordingsPath = path.join(tempDir.path, 'temp_recordings');

      // Create directory if it doesn't exist
      final directory = Directory(recordingsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      _currentRecordingPath = path.join(recordingsPath, fileName);

      // Start recording
      await _audioService.startRecording();

      // Update state
      _isRecording = true;
      _recordingStartTime = DateTime.now();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to start recording', e, stackTrace);
      return false;
    }
  }

  /// Stops the current recording and saves it as a memory entry.
  ///
  /// Returns the saved Memory if successful, null otherwise.
  Future<Memory?> stopRecording({String? title}) async {
    if (!_isRecording || _currentRecordingPath == null) {
      _loggingService.warning('Attempted to stop recording when not recording');
      return null;
    }

    try {
      // Stop the recording
      File recordingFile = await _audioService.stopRecording();

      // Create a new memory entry
      final recordingEndTime = DateTime.now();
      final durationInSeconds = recordingEndTime.difference(_recordingStartTime!).inSeconds;

      // Get file size
      final int fileSize = await recordingFile.length();

      // Create memory object
      final tempMemory = Memory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: recordingFile.path,
        timestamp: _recordingStartTime!,
        durationSeconds: durationInSeconds,
        fileSizeBytes: fileSize,
      );

      // Save memory to storage service
      final savedMemory = await _localStorageService.saveMemoryRecording(tempMemory, recordingFile);

      // Add to the list of memories and sort by timestamp (newest first)
      _memories.add(savedMemory);
      _memories.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Reset recording state
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      notifyListeners();
      return savedMemory;
    } catch (e, stackTrace) {
      _handleError('Failed to stop recording', e, stackTrace);

      // Reset recording state even if there was an error
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      notifyListeners();
      return null;
    }
  }

  /// Cancels the current recording without saving it.
  Future<bool> cancelRecording() async {
    if (!_isRecording || _currentRecordingPath == null) {
      _loggingService.warning('Attempted to cancel recording when not recording');
      return false;
    }

    try {
      // Stop the recording
      await _audioService.stopRecording();

      // Delete the file
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }

      // Reset recording state
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to cancel recording', e, stackTrace);

      // Reset recording state even if there was an error
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      notifyListeners();
      return false;
    }
  }

  /// Loads all existing memory entries from storage.
  Future<void> loadMemoryEntries() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize storage service if needed
      await _localStorageService.initialize();

      // Use the LocalStorageService to get all memories
      _memories = await _localStorageService.getAllMemories();

      // Memories are already sorted in the service method
    } catch (e, stackTrace) {
      _handleError('Failed to load memory entries', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a memory entry and its associated audio file.
  ///
  /// Returns true if deletion was successful, false otherwise.
  Future<bool> deleteMemoryEntry(String memoryId) async {
    try {
      _errorMessage = null;

      // Find the memory entry
      final entryIndex = _memories.indexWhere((entry) => entry.id == memoryId);
      if (entryIndex == -1) {
        _loggingService.warning('Attempted to delete non-existent memory entry: $memoryId');
        return false;
      }

      // Delete the memory using the storage service
      await _localStorageService.deleteMemory(memoryId);

      // Remove from the local list
      _memories.removeAt(entryIndex);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to delete memory entry', e, stackTrace);
      return false;
    }
  }

  /// Updates the title of a memory entry.
  ///
  /// Note: This method is not fully implemented because the Memory model
  /// does not have a title property. This is kept as a placeholder for
  /// future implementation.
  ///
  /// Returns true if the update was successful, false otherwise.
  Future<bool> updateMemoryTitle(String memoryId, String newTitle) async {
    try {
      _errorMessage = null;

      // Find the memory entry
      final entryIndex = _memories.indexWhere((entry) => entry.id == memoryId);
      if (entryIndex == -1) {
        _loggingService.warning('Attempted to update non-existent memory entry: $memoryId');
        return false;
      }

      // Note: The Memory model doesn't have a title property, so this method cannot be fully implemented
      _loggingService.warning('Memory title updates not supported in current model');

      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      _handleError('Failed to update memory title', e, stackTrace);
      return false;
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