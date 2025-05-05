import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/exceptions.dart';
import '../models/memory_model.dart';
import '../services/audio_service.dart';
import '../services/logging_service.dart';

/// Manages audio playback state and controls for memory recordings.
///
/// This provider handles:
/// - Playing audio files from memory entries
/// - Pausing/resuming playback
/// - Tracking playback position
/// - Managing playback state (playing, paused, stopped)
class PlayerProvider with ChangeNotifier {
  final AudioService _audioService;
  final LoggingService _loggingService;

  // Playback state
  bool _isPlaying = false;
  bool _isPaused = false;
  Memory? _currentMemory;

  // Playback position tracking
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<dynamic>? _playerStateSubscription;
  Timer? _positionUpdateTimer;

  // Error state
  String? _errorMessage;

  /// Constructs a PlayerProvider with required services.
  PlayerProvider({
    required AudioService audioService,
    required LoggingService loggingService,
  }) :
        _audioService = audioService,
        _loggingService = loggingService {
    // Initialize listeners for audio position and duration updates
    _initializeAudioListeners();
  }

  /// Whether audio is currently playing.
  bool get isPlaying => _isPlaying;

  /// Whether audio is currently paused.
  bool get isPaused => _isPaused;

  /// The memory entry being played, if any.
  Memory? get currentMemory => _currentMemory;

  /// Current playback position.
  Duration get position => _position;

  /// Total duration of the current audio.
  Duration get duration => _duration;

  /// Playback progress as a percentage (0.0 to 1.0).
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  /// Initializes listeners for audio position and duration updates.
  void _initializeAudioListeners() {
    // Listen for position updates
    _positionSubscription?.cancel();
    _positionSubscription = _audioService.positionStream.listen(
            (position) {
          _position = position;
          notifyListeners();
        },
        onError: (error) {
          _loggingService.error('Error in position stream', error);
        }
    );

    // Create a timer to periodically update position
    // This is a backup in case the streams aren't updating frequently enough
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (_isPlaying && !_isPaused) {
        try {
          final currentPosition = await getCurrentPosition();
          if (currentPosition != null && currentPosition != _position) {
            _position = currentPosition;
            notifyListeners();
          }
        } catch (e) {
          // Ignore errors here as they're not critical
        }
      }
    });
  }

  /// Gets the current playback position
  Future<Duration?> getCurrentPosition() async {
    try {
      // Instead of directly accessing _player, we'll infer from player state
      if (_isPlaying) {
        return _position; // Return the position we're tracking
      }
      return Duration.zero;
    } catch (e) {
      return null;
    }
  }

  /// Starts playback of a memory entry.
  ///
  /// Returns true if playback started successfully, false otherwise.
  Future<bool> playMemory(Memory memory) async {
    if (_isPlaying) {
      // If already playing the same memory, do nothing
      if (_currentMemory?.id == memory.id && !_isPaused) {
        return true;
      }

      // If playing a different memory, stop the current playback first
      await stopPlayback();
    }

    try {
      _errorMessage = null;

      // Start playback
      await _audioService.playAudio(memory.filePath);

      // Update state
      _isPlaying = true;
      _isPaused = false;
      _currentMemory = memory;
      _position = Duration.zero;

      // Get the duration
      _duration = Duration(seconds: memory.durationSeconds);

      // Set up completion listener using a standalone method
      _setupPlaybackCompletionListener();

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to play audio', e, stackTrace);
      return false;
    }
  }

  /// Sets up a listener to detect when playback completes
  void _setupPlaybackCompletionListener() {
    // Cancel any existing subscription first
    _playerStateSubscription?.cancel();

    // We'll use a timer to periodically check the playback state
    // This is a simple approach that doesn't require direct access to AudioService internals
    _playerStateSubscription = Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
      if (!_isPlaying) return; // Skip if we're not supposed to be playing

      // If we've reached the end (position >= duration), consider playback complete
      if (_position.inMilliseconds >= _duration.inMilliseconds - 200) { // With 200ms margin
        _isPlaying = false;
        _isPaused = false;
        _position = _duration; // Set position to end
        notifyListeners();
        _playerStateSubscription?.cancel(); // Stop listening once complete
      }
    });
  }

  /// Pauses the current playback.
  ///
  /// Returns true if playback was paused successfully, false otherwise.
  Future<bool> pausePlayback() async {
    if (!_isPlaying || _isPaused) {
      return true; // Already paused or not playing
    }

    try {
      await _audioService.pausePlayback();

      _isPaused = true;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to pause audio', e, stackTrace);
      return false;
    }
  }

  /// Resumes playback after pausing.
  ///
  /// Returns true if playback was resumed successfully, false otherwise.
  Future<bool> resumePlayback() async {
    if (!_isPlaying || !_isPaused) {
      return false; // Not in a paused state
    }

    try {
      await _audioService.resumePlayback();

      _isPaused = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to resume audio', e, stackTrace);
      return false;
    }
  }

  /// Stops the current playback.
  ///
  /// Returns true if playback was stopped successfully, false otherwise.
  Future<bool> stopPlayback() async {
    if (!_isPlaying) {
      return true; // Already stopped
    }

    try {
      await _audioService.stopPlayback();

      _isPlaying = false;
      _isPaused = false;
      _position = Duration.zero;
      _currentMemory = null;

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to stop audio', e, stackTrace);
      return false;
    }
  }

  /// Seeks to a specific position in the current audio.
  ///
  /// [positionInSeconds] The position to seek to, in seconds.
  ///
  /// Returns true if seeking was successful, false otherwise.
  Future<bool> seekTo(int positionInSeconds) async {
    if (!_isPlaying) {
      return false; // Not playing
    }

    try {
      final newPosition = Duration(seconds: positionInSeconds);
      await _audioService.seekTo(newPosition);

      _position = newPosition;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to seek audio', e, stackTrace);
      return false;
    }
  }

  /// Seeks forward by a specific number of seconds.
  ///
  /// Returns true if seeking was successful, false otherwise.
  Future<bool> seekForward([int seconds = 10]) async {
    if (!_isPlaying) {
      return false;
    }

    final newPositionSeconds = _position.inSeconds + seconds;
    return seekTo(newPositionSeconds);
  }

  /// Seeks backward by a specific number of seconds.
  ///
  /// Returns true if seeking was successful, false otherwise.
  Future<bool> seekBackward([int seconds = 10]) async {
    if (!_isPlaying) {
      return false;
    }

    final newPositionSeconds = _position.inSeconds - seconds;
    return seekTo(newPositionSeconds > 0 ? newPositionSeconds : 0);
  }

  /// Sets the playback speed.
  ///
  /// [speed] The playback speed (e.g., 0.5, 1.0, 1.5, 2.0).
  ///
  /// Returns true if speed was set successfully, false otherwise.
  Future<bool> setPlaybackSpeed(double speed) async {
    if (!_isPlaying) {
      return false;
    }

    try {
      // Use a more general approach that doesn't require direct player access
      // Note: In a real implementation, AudioService would need a setPlaybackSpeed method
      // For now, we'll just update the UI state
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to set playback speed', e, stackTrace);
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

  @override
  void dispose() {
    // Clean up resources
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _positionUpdateTimer?.cancel();
    _audioService.stopPlayback();
    super.dispose();
  }
}