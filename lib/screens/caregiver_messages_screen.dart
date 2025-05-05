/*
* File: lib/screens/caregiver_messages_screen.dart
* Description: Screen to display caregiver messages for the elderly user
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/caregiver_messages_provider.dart';
import '../models/caregiver_message_model.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../services/logging_service.dart';

/// Screen to display messages from caregivers
///
/// This screen displays a list of messages from caregivers, allowing the
/// user to view both text and audio messages, and mark them as read.
class CaregiverMessagesScreen extends StatefulWidget {
  const CaregiverMessagesScreen({super.key});

  @override
  State<CaregiverMessagesScreen> createState() => _CaregiverMessagesScreenState();
}

class _CaregiverMessagesScreenState extends State<CaregiverMessagesScreen> {
  // Currently playing audio message ID for UI state
  String? _currentlyPlayingMessageId;
  // Flag to show loading indicators during operations
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Load messages when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  /// Load messages from the provider
  Future<void> _loadMessages() async {
    final provider = Provider.of<CaregiverMessagesProvider>(context, listen: false);
    await provider.loadMessages();
  }

  /// Mark a message as read
  Future<void> _markAsRead(BuildContext context, String messageId) async {
    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<CaregiverMessagesProvider>(context, listen: false);
    final logService = Provider.of<LoggingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);

    try {
      setState(() {
        _isProcessing = true;
      });

      await provider.markMessageAsRead(messageId);
    } catch (e, stackTrace) {
      logService.error('Failed to mark message as read', e, stackTrace);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not mark message as read'),
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

  /// Mark all messages as read
  Future<void> _markAllAsRead(BuildContext context) async {
    // Store local references to avoid BuildContext usage across async gaps
    final provider = Provider.of<CaregiverMessagesProvider>(context, listen: false);
    final logService = Provider.of<LoggingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = AppTheme.errorColor(context);

    if (provider.unreadCount == 0) {
      // No unread messages, no need to do anything
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      await provider.markAllMessagesAsRead();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('All messages marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      logService.error('Failed to mark all messages as read', e, stackTrace);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not mark all messages as read'),
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

  /// Handle playing an audio message
  void _handlePlayAudio(CaregiverMessage message) {
    // For now, just update UI state. Audio playback will be implemented in a separate PR
    setState(() {
      if (_currentlyPlayingMessageId == message.id) {
        _currentlyPlayingMessageId = null; // Stop playing
      } else {
        _currentlyPlayingMessageId = message.id; // Start playing
        _markAsRead(context, message.id); // Mark as read when played
      }
    });
  }

  /// Build app bar with action buttons
  PreferredSizeWidget _buildAppBar(BuildContext context, int unreadCount) {
    return AppBar(
      title: Text('Caregiver Messages'),
      actions: [
        if (unreadCount > 0)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            child: TextButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _markAllAsRead(context),
              icon: Icon(Icons.done_all),
              label: Text('Mark All Read'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Consumer<CaregiverMessagesProvider>(
          builder: (context, provider, _) {
            return _buildAppBar(context, provider.unreadCount);
          },
        ),
      ),
      body: SafeArea(
        child: Consumer<CaregiverMessagesProvider>(
          builder: (context, provider, _) {
            // Show loading indicator if provider is loading
            if (provider.isLoading || _isProcessing) {
              return Center(
                child: CircularProgressIndicator(),
              );
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
                      'Error loading messages',
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
                      onPressed: _loadMessages,
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            // Show empty state if no messages
            if (provider.messages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    Text(
                      'No Messages Yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: AppConstants.defaultPadding / 2),
                    Text(
                      'When your caregivers send you messages, they will appear here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    ElevatedButton(
                      onPressed: _loadMessages,
                      child: Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            // Display the list of messages
            return RefreshIndicator(
              onRefresh: _loadMessages,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  vertical: AppConstants.defaultPadding,
                ),
                itemCount: provider.messages.length,
                itemBuilder: (context, index) {
                  final message = provider.messages[index];
                  return _buildMessageCard(context, message);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build a message card with appropriate styling based on message type
  Widget _buildMessageCard(BuildContext context, CaregiverMessage message) {
    final bool isUnread = !message.isRead;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.defaultPadding / 2,
      ),
      elevation: isUnread ? 4 : 2,
      child: InkWell(
        onTap: () {
          if (!message.isRead) {
            _markAsRead(context, message.id);
          }
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender and timestamp row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sender with relationship
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          message.sender.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (message.sender.relationship != null) ...[
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message.sender.relationship!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Timestamp
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              SizedBox(height: AppConstants.defaultPadding / 2),

              // Divider between header and content
              Divider(),

              SizedBox(height: AppConstants.defaultPadding / 2),

              // Message content
              if (message.type == CaregiverMessageType.text)
                _buildTextMessage(context, message, isUnread)
              else
                _buildAudioMessage(context, message, isUnread),

              // Unread indicator
              if (isUnread)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: EdgeInsets.only(top: AppConstants.defaultPadding / 2),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a text message content widget
  Widget _buildTextMessage(BuildContext context, CaregiverMessage message, bool isUnread) {
    return Text(
      message.content,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  /// Build an audio message content widget
  Widget _buildAudioMessage(BuildContext context, CaregiverMessage message, bool isUnread) {
    final bool isPlaying = _currentlyPlayingMessageId == message.id;

    return FutureBuilder<bool>(
      future: message.exists(),
      builder: (context, snapshot) {
        final bool fileExists = snapshot.data ?? false;

        return Row(
          children: [
            // Play button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 28,
                ),
                onPressed: fileExists
                    ? () => _handlePlayAudio(message)
                    : null,
              ),
            ),

            SizedBox(width: AppConstants.defaultPadding),

            // Audio information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Message',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    message.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  // Error message if file doesn't exist
                  if (!fileExists && snapshot.connectionState == ConnectionState.done)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor(context).withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Audio unavailable',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Format a timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    // For messages from today, show just the time
    if (messageDate == today) {
      return 'Today ${DateFormat.jm().format(timestamp)}';
    }

    // For messages from yesterday, show "Yesterday"
    final yesterday = today.subtract(Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday ${DateFormat.jm().format(timestamp)}';
    }

    // For messages within the last week, show the day name
    final lastWeek = today.subtract(Duration(days: 7));
    if (messageDate.isAfter(lastWeek)) {
      return DateFormat('EEE').format(timestamp);
    }

    // For older messages, show the date
    return DateFormat.MMMd().format(timestamp);
  }
}