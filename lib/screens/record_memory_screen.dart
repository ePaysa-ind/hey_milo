/*
* File: lib/screens/record_memory_screen.dart
* Description: Screen for recording new audio memories
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';

import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../providers/recordings_provider.dart';
import '../services/audio_service.dart';
import '../services/logging_service.dart';

class RecordMemoryScreen extends StatefulWidget {
  const RecordMemoryScreen({super.key});

  @override
  State<RecordMemoryScreen> createState() => _RecordMemoryScreenState();
}

class _RecordMemoryScreenState extends State<RecordMemoryScreen> {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final AudioService _audioService = GetIt.instance<AudioService>();

  // Recording state
  bool _isRecording = false;
  DateTime? _startTime;
  Duration _recordingDuration = Duration.zero;
  double _audioLevel = 0.0;

  // Timers
  Timer? _durationTimer;
  Timer? _audioLevelTimer;

  // Maximum recording duration
  final int _maxRecordingSeconds = AppConstants.maxRecordingDurationSeconds;

  @override
  void initState() {
    super.initState();
    _logger.info('RecordMemoryScreen: Initializing record memory screen');
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _startTimers() {
    // Timer to update recording duration
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _startTime != null) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_startTime!);

          // Auto-stop if max duration reached
          if (_recordingDuration.inSeconds >= _maxRecordingSeconds) {
            _stopRecording();
          }
        });
      }
    });

    // Timer to update audio level
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (mounted && _isRecording) {
        final volume = await _audioService.getRecordingVolume();
        if (mounted) {
          setState(() {
            _audioLevel = volume;
          });
        }
      }
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;

    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
  }

  Future<void> _startRecording() async {
    _logger.info('RecordMemoryScreen: Starting recording');

    // Store a local reference to avoid async gap issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final recordingsProvider = context.read<RecordingsProvider>();

    try {
      final success = await recordingsProvider.startRecording();

      if (!mounted) return;

      if (success) {
        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
          _recordingDuration = Duration.zero;
          _audioLevel = 0.0;
        });

        _startTimers();
      } else {
        _showErrorSnackBar(scaffoldMessenger, 'Failed to start recording');
      }
    } catch (e) {
      _logger.error('RecordMemoryScreen: Error starting recording', e);
      if (mounted) {
        _showErrorSnackBar(scaffoldMessenger, 'Could not start recording');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _logger.info('RecordMemoryScreen: Stopping recording');
    _stopTimers();

    // Store a local reference to avoid async gap issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recordingsProvider = context.read<RecordingsProvider>();

    try {
      final memory = await recordingsProvider.stopRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      if (memory != null) {
        _showSuccessSnackBar(scaffoldMessenger, 'Memory saved successfully');
        navigator.pop();
      } else {
        _showErrorSnackBar(scaffoldMessenger, 'Failed to save recording');
      }
    } catch (e) {
      _logger.error('RecordMemoryScreen: Error stopping recording', e);

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        _showErrorSnackBar(scaffoldMessenger, 'Could not save recording');
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    _logger.info('RecordMemoryScreen: Cancelling recording');
    _stopTimers();

    // Store a local reference to avoid async gap issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recordingsProvider = context.read<RecordingsProvider>();

    try {
      await recordingsProvider.cancelRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      navigator.pop();
    } catch (e) {
      _logger.error('RecordMemoryScreen: Error cancelling recording', e);

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        _showErrorSnackBar(scaffoldMessenger, 'Error cancelling recording');
      }
    }
  }

  void _showErrorSnackBar(ScaffoldMessengerState messengerState, String message) {
    messengerState.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor(context),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(ScaffoldMessengerState messengerState, String message) {
    messengerState.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor(context),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_isRecording) return true;

    // Capture context-dependent values before async operation
    final navigator = Navigator.of(context);

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Recording?'),
        content: const Text(
          'If you go back now, your current recording will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop(false);
            },
            child: const Text('Continue Recording'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor(dialogContext),
            ),
            onPressed: () {
              navigator.pop(true);
            },
            child: const Text('Discard Recording'),
          ),
        ],
      ),
    ) ?? false;

    if (shouldPop && mounted) {
      await _cancelRecording();
    }

    return shouldPop;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Capture context-dependent values before async operation
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();

        // Check if still mounted after async operation
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Record Memory'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // Capture context-dependent values before async operation
              final navigator = Navigator.of(context);
              final shouldPop = await _onWillPop();

              // Check if still mounted after async operation
              if (shouldPop && mounted) {
                navigator.pop();
              }
            },
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildRecordingUI(),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isRecording
                ? 'Recording in progress...'
                : 'Tap the microphone to start recording',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppConstants.defaultPadding * 2),
          _buildRecordingVisual(),
          SizedBox(height: AppConstants.defaultPadding * 2),
          _buildTimerDisplay(),
          SizedBox(height: AppConstants.defaultPadding),
          if (_isRecording) _buildMaxDurationIndicator(),
        ],
      ),
    );
  }

  Widget _buildRecordingVisual() {
    final size = MediaQuery.of(context).size.width * 0.5;
    final buttonSize = size * 0.8;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Sound level visualization
        if (_isRecording)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withAlpha(25),
            ),
            child: CustomPaint(
              painter: SoundLevelPainter(
                level: _audioLevel,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

        // Recording button
        InkWell(
          onTap: _isRecording ? _stopRecording : _startRecording,
          borderRadius: BorderRadius.circular(buttonSize),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording
                  ? AppTheme.errorColor(context)
                  : Theme.of(context).colorScheme.primary,
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: buttonSize * 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerDisplay() {
    // Format the recording duration
    final minutes = _recordingDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (_recordingDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRecording)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorColor(context),
            ),
          ),
        if (_isRecording)
          SizedBox(width: AppConstants.defaultPadding / 2),
        Text(
          '$minutes:$seconds',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildMaxDurationIndicator() {
    final progress = _recordingDuration.inSeconds / _maxRecordingSeconds;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.surface,
          color: progress > 0.8
              ? AppTheme.errorColor(context)
              : Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: AppConstants.defaultPadding / 2),
        Text(
          'Maximum recording time: ${_maxRecordingSeconds ~/ 60} minutes',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_isRecording) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
            SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic),
                label: const Text('Start Recording'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SoundLevelPainter extends CustomPainter {
  final double level;
  final Color color;

  SoundLevelPainter({
    required this.level,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw sound waves
    for (int i = 1; i <= 4; i++) {
      // Calculate alpha value as integer
      final alphaValue = ((level * 0.8) - (i * 0.15)) * 255;
      final alphaClamped = alphaValue <= 0 ? 0 : (alphaValue >= 255 ? 255 : alphaValue.toInt());

      final Paint paint = Paint()
        ..color = color.withAlpha(alphaClamped)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      if (paint.color.a <= 0) continue;

      final wavePath = Path();
      final waveRadius = radius * (0.6 + (i * 0.1));

      for (int angle = 0; angle < 360; angle += 45) {
        final radians = angle * pi / 180;
        final x = center.dx + waveRadius * cos(radians);
        final y = center.dy + waveRadius * sin(radians);

        if (angle == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }

      wavePath.close();
      canvas.drawPath(wavePath, paint);
    }
  }

  @override
  bool shouldRepaint(SoundLevelPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}