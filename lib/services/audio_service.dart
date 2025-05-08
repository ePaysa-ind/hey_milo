/*
* file path: lib/services/audio_service.dart
* Audio Service for the Milo App
* Handles all audio recording and playback functionality.
* Author: Milo App Development Team
* Last Updated: May 5, 2025 - Corrected for record package v6.x API
*/

import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// Ensure correct imports for both classes from the record package
import 'package:record/record.dart'; // Provides AudioRecorder, AudioEncoder, Amplitude, RecordConfig etc.
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; // Added for audio session configuration
import '../core/exceptions.dart'; // Assuming these exist
import '../services/logging_service.dart'; // Assuming this exists
import '../services/permission_service.dart'; // Assuming this exists
import 'package:get_it/get_it.dart';

class AudioService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final PermissionService _permissionService =
      GetIt.instance<PermissionService>();

  final AudioPlayer _player = AudioPlayer();
  // --- FIX 1: Use AudioRecorder instead of Record ---
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _playerPositionSubscription;
  // Using broadcast controller is fine if multiple listeners need position
  final StreamController<Duration> _positionStreamController =
      StreamController<Duration>.broadcast();

  Stream<Duration> get positionStream => _positionStreamController.stream;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  // Dispose flag to prevent operations after disposal
  bool _isDisposed = false;

  AudioService() {
    initialize(); // Call initialize from constructor or an explicit init method
  }

  Future<void> initialize() async {
    if (_isDisposed) return;
    try {
      _logger.info('AudioService: Initializing audio service');

      // Configure audio session - ADDED THIS SECTION
      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration.speech());
        _logger.info('AudioService: Audio session configured');
      } catch (e) {
        _logger.error('AudioService: Failed to configure audio session: $e');
        // Don't throw here, continue initialization
      }

      // Listen to position stream
      _playerPositionSubscription = _player.positionStream.listen(
        (position) {
          if (!_positionStreamController.isClosed) {
            _positionStreamController.add(position);
          }
        },
        onError: (error) {
          if (!_positionStreamController.isClosed) {
            _positionStreamController.addError(error); // Propagate errors
          }
          _logger.error(
            'AudioService: Error in player position stream: $error',
          );
        },
        onDone: () {
          // Handle stream closing if necessary
          _logger.info('AudioService: Player position stream done.');
        },
        cancelOnError: false, // Keep listening even after errors if desired
      );

      // Listen to player state changes
      _player.playerStateStream.listen(
        (state) {
          _isPlaying = state.playing; // Update isPlaying based on player state

          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false; // Ensure flag is false on completion
            // Optionally reset position or notify UI
            if (!_positionStreamController.isClosed) {
              // Reset position to 0 when completed? Or use player.duration?
              _positionStreamController.add(Duration.zero);
            }
          }
        },
        onError: (error) {
          _logger.error('AudioService: Error in player state stream: $error');
          _isPlaying = false; // Assume not playing on error
        },
      );

      _logger.info('AudioService: Successfully initialized audio service');
    } catch (e) {
      _logger.error('AudioService: Failed to initialize audio service: $e');
      // Consider if throwing here prevents app launch, maybe handle differently
      throw AudioException(
        message: 'Failed to initialize audio service: $e',
        code: 'AUDIO_INIT',
      );
    }
  }

  Future<String> startRecording() async {
    if (_isDisposed) {
      throw AudioException(message: 'Service disposed', code: 'AUDIO_DISPOSED');
    }
    try {
      _logger.info('AudioService: Attempting to start recording');

      if (_isRecording) {
        _logger.warning(
          'AudioService: Start recording called while already recording.',
        );
        throw AudioException(
          message: 'Already recording',
          code: 'AUDIO_ALREADY_RECORDING',
        );
      }

      final bool hasPermission =
          await _permissionService.requestMicrophonePermission();
      if (!hasPermission) {
        _logger.error('AudioService: Microphone permission denied.');
        throw PermissionException(
          message: 'Microphone permission denied',
          code: 'MIC_PERMISSION_DENIED',
        );
      }

      // Use getApplicationDocumentsDirectory for persistent storage or
      // getTemporaryDirectory for temporary files. Temporary is often better for recordings
      // before they are explicitly saved/managed elsewhere.
      final Directory tempDir = await getTemporaryDirectory();
      // Ensure consistent file naming, m4a is typical for aacLc
      final String tempFilePath = path.join(
        tempDir.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      // --- FIX 2: Methods (start, stop, etc.) are called on AudioRecorder instance ---
      // Define the recording configuration
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // Defined in the record package
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording to file
      await _recorder.start(config, path: tempFilePath);

      _isRecording = true;
      _logger.info('AudioService: Started recording to $tempFilePath');
      return tempFilePath;
    } catch (e) {
      _logger.error('AudioService: Failed to start recording: $e');
      _isRecording = false; // Ensure state is reset on error
      // Consider specific error types from the record package if available
      throw AudioException(
        message: 'Failed to start recording: ${e.toString()}',
        code: 'AUDIO_START_ERROR',
      );
    }
  }

  Future<File> stopRecording() async {
    if (_isDisposed) {
      throw AudioException(message: 'Service disposed', code: 'AUDIO_DISPOSED');
    }
    if (!_isRecording) {
      _logger.warning(
        'AudioService: Stop recording called when not recording.',
      );
      throw AudioException(
        message: 'Not currently recording',
        code: 'AUDIO_NOT_RECORDING',
      );
    }

    try {
      _logger.info('AudioService: Stopping recording');

      // --- FIX 2: Methods (start, stop, etc.) are called on AudioRecorder instance ---
      final String? recordingPath = await _recorder.stop();
      _isRecording = false; // Update state immediately

      if (recordingPath == null || recordingPath.isEmpty) {
        _logger.error(
          'AudioService: Recording stopped but no path was returned.',
        );
        throw AudioException(
          message: 'Recording failed - no file produced',
          code: 'AUDIO_NO_FILE',
        );
      }

      final File recordingFile = File(recordingPath);
      // Use async check for existence
      if (!await recordingFile.exists()) {
        _logger.error(
          'AudioService: Recording stopped, path returned, but file missing at $recordingPath',
        );
        throw AudioException(
          message: 'Recording file does not exist at path: $recordingPath',
          code: 'AUDIO_FILE_MISSING',
        );
      }

      _logger.info(
        'AudioService: Recording stopped and saved at $recordingPath',
      );
      return recordingFile;
    } catch (e) {
      _logger.error('AudioService: Failed to stop recording: $e');
      _isRecording = false; // Ensure state is reset on error
      throw AudioException(
        message: 'Failed to stop recording: ${e.toString()}',
        code: 'AUDIO_STOP_ERROR',
      );
    }
  }

  Future<void> playAudio(String filePath) async {
    if (_isDisposed) {
      throw AudioException(message: 'Service disposed', code: 'AUDIO_DISPOSED');
    }
    try {
      _logger.info('AudioService: Attempting to play audio from: $filePath');

      final File audioFile = File(filePath);
      if (!await audioFile.exists()) {
        _logger.error(
          'AudioService: Audio file not found for playback: $filePath',
        );
        throw AudioException(
          message: 'Audio file does not exist: $filePath',
          code: 'AUDIO_FILE_NOT_FOUND',
        );
      }

      // Stop current playback before starting new one, if any
      if (_isPlaying || _player.processingState != ProcessingState.idle) {
        _logger.info(
          'AudioService: Stopping previous playback before starting new one.',
        );
        await _player.stop(); // Use stop() to reset state properly
        _isPlaying = false; // Ensure state is updated
      }

      // Using setFilePath might be less robust than setAudioSource with FileSource
      // Consider using AudioSource.uri(Uri.file(filePath)) for consistency
      await _player.setAudioSource(AudioSource.uri(Uri.file(filePath)));
      // Don't await play() if you want the function to return while audio starts
      _player.play(); // Starts playback asynchronously

      // Note: _isPlaying will be updated by the playerStateStream listener
      // Setting it true here might be premature if loading takes time.
      // Rely on the stream listener for accurate state.
      // _isPlaying = true; // Removed this line

      _logger.info('AudioService: Playback initiated for $filePath');
    } catch (e) {
      _logger.error('AudioService: Failed to play audio: $e');
      _isPlaying = false; // Ensure state is reset on error
      // Consider catching specific PlayerException types
      throw AudioException(
        message: 'Failed to play audio: ${e.toString()}',
        code: 'AUDIO_PLAY_ERROR',
      );
    }
  }

  Future<void> pausePlayback() async {
    if (_isDisposed) return; // Don't throw on pause/resume/stop if disposed
    try {
      if (!_player.playing) return; // Use player's state directly
      await _player.pause();
      // _isPlaying will be updated by the listener
      _logger.info('AudioService: Playback paused');
    } catch (e) {
      _logger.error('AudioService: Failed to pause playback: $e');
      throw AudioException(
        message: 'Failed to pause playback: ${e.toString()}',
        code: 'AUDIO_PAUSE_ERROR',
      );
    }
  }

  Future<void> resumePlayback() async {
    if (_isDisposed) return;
    try {
      // Check if player is paused (ready or completed but seek back might also allow play)
      if (_player.playing) return; // Already playing
      // Check if we are in a state where play can be called
      if (_player.processingState == ProcessingState.idle ||
          _player.processingState == ProcessingState.loading) {
        _logger.warning(
          'AudioService: Cannot resume playback, player not ready.',
        );
        return;
      }
      await _player.play();
      // _isPlaying will be updated by the listener
      _logger.info('AudioService: Playback resumed');
    } catch (e) {
      _logger.error('AudioService: Failed to resume playback: $e');
      throw AudioException(
        message: 'Failed to resume playback: ${e.toString()}',
        code: 'AUDIO_RESUME_ERROR',
      );
    }
  }

  Future<void> stopPlayback() async {
    if (_isDisposed) return;
    try {
      // Check if there's anything to stop
      if (_player.processingState == ProcessingState.idle) return;

      await _player.stop(); // stop() also resets position
      // _isPlaying will be updated by the listener
      _logger.info('AudioService: Playback stopped');
    } catch (e) {
      _logger.error('AudioService: Failed to stop playback: $e');
      throw AudioException(
        message: 'Failed to stop playback: ${e.toString()}',
        code: 'AUDIO_STOP_PLAYBACK',
      );
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_isDisposed) {
      throw AudioException(message: 'Service disposed', code: 'AUDIO_DISPOSED');
    }
    try {
      // Allow seeking even if paused, but maybe not if idle/loading? Check package behavior.
      // if (_player.processingState != ProcessingState.ready && _player.processingState != ProcessingState.completed) return;
      if (_player.duration == null) {
        _logger.warning('AudioService: Cannot seek, duration unknown.');
        return; // Cannot seek if duration isn't known
      }
      // Ensure seek position is valid
      final validPosition =
          position.isNegative
              ? Duration.zero
              : (position > _player.duration! ? _player.duration! : position);

      await _player.seek(validPosition);
      _logger.info('AudioService: Seek to ${validPosition.inSeconds}s');
    } catch (e) {
      _logger.error('AudioService: Seek failed: $e');
      throw AudioException(
        message: 'Seek failed: ${e.toString()}',
        code: 'AUDIO_SEEK_ERROR',
      );
    }
  }

  // Getting duration might not require creating a new player instance.
  // The primary player might hold the duration after setAudioSource/load.
  // However, this approach works if you need duration before playing with the main player.
  Future<Duration> getAudioDuration(String filePath) async {
    if (_isDisposed) {
      throw AudioException(message: 'Service disposed', code: 'AUDIO_DISPOSED');
    }
    final AudioPlayer tempPlayer = AudioPlayer(); // Create temporary player
    try {
      _logger.info('AudioService: Getting duration for: $filePath');
      final File audioFile = File(filePath);
      if (!await audioFile.exists()) {
        _logger.error(
          'AudioService: Audio file not found for duration check: $filePath',
        );
        throw AudioException(
          message: 'Audio file does not exist: $filePath',
          code: 'AUDIO_DURATION_FILE_MISSING',
        );
      }

      // Using setFilePath might be less reliable than setAudioSource
      // final Duration? duration = await tempPlayer.setFilePath(filePath);
      final Duration? duration = await tempPlayer.setAudioSource(
        AudioSource.uri(Uri.file(filePath)),
      );

      _logger.info(
        'AudioService: Duration for $filePath is ${duration ?? 'unknown'}',
      );
      return duration ?? Duration.zero;
    } catch (e) {
      _logger.error('AudioService: Failed to get duration for $filePath: $e');
      throw AudioException(
        message: 'Failed to get audio duration: ${e.toString()}',
        code: 'AUDIO_DURATION_ERROR',
      );
    } finally {
      // Ensure temporary player is always disposed
      await tempPlayer.dispose();
    }
  }

  Future<double> getRecordingVolume() async {
    if (_isDisposed || !_isRecording) return 0.0; // Check disposed state

    try {
      // --- FIX 2 & 3: Use AudioRecorder instance and correct Amplitude property ---
      final Amplitude amplitude = await _recorder.getAmplitude();

      // Use amplitude.max for max dBFS, amplitude.current for current dBFS
      // Ensure values are finite before calculations
      final double maxDb =
          amplitude.max.isFinite
              ? amplitude.max
              : -160.0; // Use max or a very low dB floor

      // Normalize dBFS (usually -160 to 0) to a 0.0-1.0 range
      // Adding 160 makes range 0 to 160, dividing by 160 normalizes.
      // Adjust the range (-160) if your recorder uses a different dBFS floor.
      final double normalized = (maxDb + 160.0) / 160.0;

      return normalized.clamp(
        0.0,
        1.0,
      ); // Clamp to ensure it stays within 0.0-1.0
    } catch (e) {
      _logger.error('AudioService: Failed to get recording volume: $e');
      return 0.0; // Return default on error
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true; // Set flag immediately
    _logger.info('AudioService: Disposing audio resources');
    try {
      // Use try-finally or individual try-catch blocks for robust disposal

      // Stop recorder if active
      if (await _recorder.isRecording()) {
        // Check state before stopping
        await _recorder.stop();
      }
      await _recorder.dispose(); // Dispose the recorder itself
      _isRecording = false; // Update state after disposal

      // Stop player if active
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        await _player.stop();
      }
      await _player.dispose(); // Dispose the player
      _isPlaying = false; // Update state after disposal

      await _playerPositionSubscription?.cancel();
      await _positionStreamController.close();

      _logger.info('AudioService: Successfully disposed audio resources');
    } catch (e) {
      // Log error but don't rethrow from dispose
      _logger.error('AudioService: Error during dispose: $e');
    }
  }
}
