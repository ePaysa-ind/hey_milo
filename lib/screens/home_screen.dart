/*
* File: lib/screens/home_screen.dart
* Description: Main home screen showing memory recordings list
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path;

import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../models/memory_model.dart';
import '../providers/recordings_provider.dart';
import '../providers/player_provider.dart';
import '../services/logging_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LoggingService _logger = GetIt.instance<LoggingService>();

  @override
  void initState() {
    super.initState();
    _logger.info('HomeScreen: Initializing home screen');
    // Load memories when the screen is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsProvider>().loadMemoryEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Memories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.medication_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/medications');
            },
            tooltip: 'Medications',
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/caregiver-messages');
            },
            tooltip: 'Caregiver Messages',
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/record-memory');
        },
        tooltip: 'Record a new memory',
        child: const Icon(Icons.mic),
      ),
      bottomNavigationBar: _buildAudioPlayer(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<RecordingsProvider>(
      builder: (context, recordingsProvider, child) {
        if (recordingsProvider.isLoading) {
          return _buildLoadingState();
        }

        if (recordingsProvider.errorMessage != null) {
          return _buildErrorState(recordingsProvider.errorMessage!);
        }

        if (recordingsProvider.memories.isEmpty) {
          return _buildEmptyState();
        }

        return _buildMemoriesList(recordingsProvider.memories);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: AppConstants.defaultPadding),
          Text(
            'Loading your memories...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
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
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.defaultPadding / 2),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.defaultPadding),
            ElevatedButton(
              onPressed: () {
                context.read<RecordingsProvider>().loadMemoryEntries();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No memories recorded yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.defaultPadding / 2),
            Text(
              'Tap the microphone button below to record your first memory',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppConstants.defaultPadding * 2),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/record-memory');
              },
              icon: const Icon(Icons.mic),
              label: const Text('Record Memory'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoriesList(List<Memory> memories) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<RecordingsProvider>().loadMemoryEntries();
      },
      child: ListView.builder(
        padding: EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: memories.length,
        itemBuilder: (context, index) {
          final memory = memories[index];
          return _buildMemoryListItem(memory);
        },
      ),
    );
  }

  Widget _buildMemoryListItem(Memory memory) {
    // Format date for display
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final dateString = dateFormat.format(memory.timestamp);
    final timeString = timeFormat.format(memory.timestamp);

    // Format duration for display
    final minutes = memory.durationSeconds ~/ 60;
    final seconds = memory.durationSeconds % 60;
    final durationString = '$minutes:${seconds.toString().padLeft(2, '0')}';

    // Format file size for display
    final fileSizeKb = memory.fileSizeBytes / 1024;
    final fileSizeMb = fileSizeKb / 1024;
    final sizeString = fileSizeMb >= 1
        ? '${fileSizeMb.toStringAsFixed(1)} MB'
        : '${fileSizeKb.toStringAsFixed(0)} KB';

    // Get file name from path
    final fileName = path.basename(memory.filePath);

    return Card(
      margin: EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: InkWell(
        onTap: () {
          _playMemory(memory);
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(50),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    padding: EdgeInsets.all(AppConstants.defaultPadding),
                    child: Icon(
                      Icons.mic,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: AppConstants.defaultPadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppConstants.defaultPadding / 2),
                        Text(
                          dateString,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          timeString,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppConstants.defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        durationString,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SizedBox(width: AppConstants.defaultPadding),
                      Icon(
                        Icons.storage_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        sizeString,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  _buildMemoryActions(memory),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryActions(Memory memory) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            _playMemory(memory);
          },
          tooltip: 'Play Memory',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            _showDeleteConfirmationDialog(memory);
          },
          tooltip: 'Delete Memory',
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmationDialog(Memory memory) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Memory?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'This will permanently delete this memory recording.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: AppConstants.defaultPadding),
                Text(
                  'This action cannot be undone.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor(context),
              ),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                await context.read<RecordingsProvider>().deleteMemoryEntry(memory.id);
              },
            ),
          ],
        );
      },
    );
  }

  void _playMemory(Memory memory) {
    context.read<PlayerProvider>().playMemory(memory);
  }

  Widget _buildAudioPlayer(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        // Check if player should be shown - based on if there's a current memory
        if (playerProvider.currentMemory == null) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Theme.of(context).colorScheme.surface,
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppConstants.defaultPadding / 2),
                  Expanded(
                    child: Text(
                      path.basename(playerProvider.currentMemory!.filePath),
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      // Instead of calling hidePlayer(), stop playback
                      playerProvider.stopPlayback();
                    },
                    tooltip: 'Close player',
                  ),
                ],
              ),
              SizedBox(height: AppConstants.defaultPadding / 2),
              // Use StreamBuilder for position updates
              ValueListenableBuilder<Duration>(
                valueListenable: ValueNotifier<Duration>(playerProvider.position),
                builder: (context, position, _) {
                  final duration = playerProvider.duration;

                  return Column(
                    children: [
                      Slider(
                        value: position.inMilliseconds.toDouble(),
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          final newDuration = Duration(milliseconds: value.toInt());
                          playerProvider.seekTo(newDuration.inSeconds);
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultPadding,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(duration),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: AppConstants.defaultPadding / 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      playerProvider.seekBackward(10);
                    },
                    tooltip: 'Skip back 10 seconds',
                    iconSize: 32,
                  ),
                  SizedBox(width: AppConstants.defaultPadding),
                  IconButton(
                    icon: Icon(
                      playerProvider.isPlaying && !playerProvider.isPaused
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    onPressed: () {
                      if (playerProvider.isPlaying) {
                        if (playerProvider.isPaused) {
                          playerProvider.resumePlayback();
                        } else {
                          playerProvider.pausePlayback();
                        }
                      } else {
                        // If not playing at all, replay the current memory
                        if (playerProvider.currentMemory != null) {
                          playerProvider.playMemory(playerProvider.currentMemory!);
                        }
                      }
                    },
                    tooltip: playerProvider.isPlaying && !playerProvider.isPaused ? 'Pause' : 'Play',
                    iconSize: 48,
                  ),
                  SizedBox(width: AppConstants.defaultPadding),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      playerProvider.seekForward(10);
                    },
                    tooltip: 'Skip forward 10 seconds',
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}