/*
* File: lib/providers/caregiver_messages_provider.dart
* Description: Provider for managing caregiver messaging functionality
* Date: May 5, 2025
* Author: Milo App Development Team
*/

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/exceptions.dart';
import '../models/caregiver_message_model.dart';
import '../services/local_storage_service.dart';
import '../services/logging_service.dart';
import '../config/constants.dart';

// WebhookService will be implemented in R1
// import '../services/webhook_service.dart';

/// Manages caregiver messaging functionality.
///
/// This provider handles:
/// - Storing and retrieving caregiver messages
/// - Sending messages to caregivers
/// - Receiving messages from caregivers
/// - Managing message state (read/unread)
class CaregiverMessagesProvider with ChangeNotifier {
  final LocalStorageService _localStorageService;
  final LoggingService _loggingService;
  // WebhookService will be implemented in R1
  // final WebhookService? _webhookService;

  // Messages state
  List<CaregiverMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Caregiver contacts
  List<Caregiver> _caregivers = [];

  // Path constants
  final String _caregiverDirectoryName = AppConstants.defaultCaregiverMessagesDirectoryName;

  // File size limits
  final int _maxMessageSizeMb = AppConstants.maxCaregiverMessageSizeMb;

  /// Constructs a CaregiverMessagesProvider with required services.
  CaregiverMessagesProvider({
    required LocalStorageService localStorageService,
    required LoggingService loggingService,
    // WebhookService will be implemented in R1
    // WebhookService? webhookService,
  }) :
        _localStorageService = localStorageService,
        _loggingService = loggingService
  // WebhookService will be implemented in R1
  // _webhookService = webhookService
  {
    // Load existing messages and contacts when provider is initialized
    loadMessages();
    loadCaregivers();
  }

  /// All available messages.
  List<CaregiverMessage> get messages => _messages;

  /// All available caregivers.
  List<Caregiver> get caregivers => _caregivers;

  /// Whether messages are currently being loaded.
  bool get isLoading => _isLoading;

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  /// Count of unread messages.
  int get unreadCount => _messages.where((message) => !message.isRead).length;

  /// Loads all existing messages from storage.
  Future<void> loadMessages() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _localStorageService.initialize();
      final messages = await _localStorageService.getAllCaregiverMessages();

      _messages = messages;

      // Sort messages by timestamp (newest first)
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e, stackTrace) {
      _handleError('Failed to load messages', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all caregivers from storage.
  Future<void> loadCaregivers() async {
    try {
      await _localStorageService.initialize();
      // In the first version, we'll use a simple list of caregivers
      // This will be expanded in future versions to load from storage

      // Add a default caregiver if none exist yet
      if (_caregivers.isEmpty) {
        _caregivers = [
          Caregiver(
            id: const Uuid().v4(),
            name: 'Family Member',
            relationship: 'Family',
          ),
        ];
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _loggingService.error('Failed to load caregivers', e, stackTrace);
    }
  }

  /// Sends a text message to a caregiver.
  ///
  /// Returns the sent message if successful, null otherwise.
  Future<CaregiverMessage?> sendTextMessage(String content, Caregiver caregiver) async {
    try {
      _errorMessage = null;

      // Check message size limit (approximate - text is usually small)
      if (content.length > _maxMessageSizeMb * 1024 * 1024) {
        throw StorageException(
            code: 'MESSAGE_TOO_LARGE',
            message: 'Message exceeds the maximum size of $_maxMessageSizeMb MB'
        );
      }

      // Create a new message
      final message = CaregiverMessage.text(
        id: const Uuid().v4(),
        sender: caregiver,
        text: content,
        timestamp: DateTime.now(),
      );

      // Add to the list of messages
      _messages.insert(0, message); // Add to the beginning (newest first)

      // Save to storage
      await _localStorageService.saveCaregiverMessage(message);

      // WebhookService will be implemented in R1
      /*
      // Send via webhook if available (for Release 1)
      if (_webhookService != null) {
        try {
          await _webhookService!.sendCaregiverMessage(
            message: content,
            caregiver: caregiver,
          );
        } catch (e, stackTrace) {
          _loggingService.warning(
            'Failed to send message via webhook, but message was saved locally',
            e,
            stackTrace,
          );
        }
      }
      */

      notifyListeners();
      return message;
    } catch (e, stackTrace) {
      _handleError('Failed to send message', e, stackTrace);
      return null;
    }
  }

  /// Adds a received audio message from a caregiver.
  ///
  /// Returns the created message if successful, null otherwise.
  Future<CaregiverMessage?> sendAudioMessage(File audioFile, Caregiver caregiver, int durationSeconds) async {
    try {
      _errorMessage = null;

      // Check file size
      final fileSize = await audioFile.length();
      if (fileSize > _maxMessageSizeMb * 1024 * 1024) {
        throw StorageException(
            code: 'MESSAGE_TOO_LARGE',
            message: 'Audio message exceeds the maximum size of $_maxMessageSizeMb MB'
        );
      }

      // Ensure we don't exceed maximum duration
      if (durationSeconds > AppConstants.maxRecordingDurationSeconds) {
        throw StorageException(
            code: 'MESSAGE_TOO_LONG',
            message: 'Audio message exceeds the maximum duration of ${AppConstants.maxRecordingDurationSeconds} seconds'
        );
      }

      // Save the audio file to the app's directory
      final savedFile = await _saveAudioFile(audioFile);

      // Create a new message
      final message = CaregiverMessage.audio(
        id: const Uuid().v4(),
        sender: caregiver,
        filePath: savedFile.path,
        durationSeconds: durationSeconds,
        timestamp: DateTime.now(),
      );

      // Add to the list of messages
      _messages.insert(0, message); // Add to the beginning (newest first)

      // Save to storage
      await _localStorageService.saveCaregiverMessage(message);

      notifyListeners();
      return message;
    } catch (e, stackTrace) {
      _handleError('Failed to send audio message', e, stackTrace);
      return null;
    }
  }

  /// Adds a received message from a caregiver.
  ///
  /// This is used when a message is received from an external source.
  /// Returns true if the message was added successfully, false otherwise.
  Future<bool> addReceivedMessage({
    required Caregiver sender,
    required String content,
    required CaregiverMessageType type,
    int? durationSeconds,
    DateTime? timestamp,
  }) async {
    try {
      _errorMessage = null;

      // Create a new message based on type
      CaregiverMessage message;

      if (type == CaregiverMessageType.text) {
        message = CaregiverMessage.text(
          sender: sender,
          text: content,
          timestamp: timestamp,
        );
      } else {
        if (durationSeconds == null) {
          throw ArgumentError('Duration is required for audio messages');
        }

        message = CaregiverMessage.audio(
          sender: sender,
          filePath: content,
          durationSeconds: durationSeconds,
          timestamp: timestamp,
        );
      }

      // Add to the list of messages
      _messages.insert(0, message); // Add to the beginning (newest first)

      // Save to storage
      await _localStorageService.saveCaregiverMessage(message);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to add received message', e, stackTrace);
      return false;
    }
  }

  /// Marks a message as read.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      _errorMessage = null;

      // Find the message
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) {
        _loggingService.warning('Attempted to mark non-existent message as read: $messageId');
        return false;
      }

      // Skip if already read
      if (_messages[index].isRead) return true;

      // Update the message
      final updatedMessage = _messages[index].markAsRead();
      _messages[index] = updatedMessage;

      // Save to storage
      await _localStorageService.saveCaregiverMessage(updatedMessage);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to mark message as read', e, stackTrace);
      return false;
    }
  }

  /// Marks all messages as read.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> markAllMessagesAsRead() async {
    try {
      _errorMessage = null;

      // Check if there are any unread messages
      if (_messages.every((message) => message.isRead)) return true;

      // Update all messages with retry logic
      List<CaregiverMessage> updatedMessages = [];
      int retryCount = 0;
      bool success = false;

      while (!success && retryCount < AppConstants.maxRetryAttempts) {
        try {
          for (final message in _messages) {
            if (!message.isRead) {
              final updatedMessage = message.markAsRead();
              updatedMessages.add(updatedMessage);
              await _localStorageService.saveCaregiverMessage(updatedMessage);
            } else {
              updatedMessages.add(message);
            }
          }
          success = true;
        } catch (e) {
          retryCount++;
          if (retryCount >= AppConstants.maxRetryAttempts) {
            rethrow;
          }
          await Future.delayed(AppConstants.retryDelay);
        }
      }

      _messages = updatedMessages;

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to mark all messages as read', e, stackTrace);
      return false;
    }
  }

  /// Deletes a message.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> deleteMessage(String messageId) async {
    try {
      _errorMessage = null;

      // Find the message
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) {
        _loggingService.warning('Attempted to delete non-existent message: $messageId');
        return false;
      }

      // Remove the message
      final message = _messages.removeAt(index);

      // Delete from storage
      await _localStorageService.deleteCaregiverMessage(message.id);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to delete message', e, stackTrace);
      return false;
    }
  }

  /// Adds a new caregiver.
  ///
  /// Returns the added caregiver if successful, null otherwise.
  Future<Caregiver?> addCaregiver(String name, {String? relationship}) async {
    try {
      _errorMessage = null;

      // Create a new caregiver
      final caregiver = Caregiver(
        id: const Uuid().v4(),
        name: name,
        relationship: relationship,
      );

      // Add to the list of caregivers
      _caregivers.add(caregiver);

      // Save to storage - we don't have a method for this yet in LocalStorageService
      // This will be implemented in a future version
      _loggingService.info('Added caregiver: ${caregiver.name}');

      notifyListeners();
      return caregiver;
    } catch (e, stackTrace) {
      _handleError('Failed to add caregiver', e, stackTrace);
      return null;
    }
  }

  /// Updates an existing caregiver.
  ///
  /// Returns the updated caregiver if successful, null otherwise.
  Future<Caregiver?> updateCaregiver(Caregiver caregiver) async {
    try {
      _errorMessage = null;

      // Find the caregiver
      final index = _caregivers.indexWhere((c) => c.id == caregiver.id);
      if (index == -1) {
        throw StorageException(
            code: 'CAREGIVER_NOT_FOUND',
            message: 'The caregiver you are trying to update does not exist.'
        );
      }

      // Update the caregiver
      _caregivers[index] = caregiver;

      // No storage method yet - will be implemented in future version
      _loggingService.info('Updated caregiver: ${caregiver.name}');

      // Update caregiver name in messages
      List<CaregiverMessage> updatedMessages = [];
      bool messagesChanged = false;

      for (final message in _messages) {
        if (message.sender.id == caregiver.id) {
          // Create a new message with updated caregiver
          final updatedMessage = CaregiverMessage(
            id: message.id,
            sender: caregiver,
            timestamp: message.timestamp,
            type: message.type,
            content: message.content,
            durationSeconds: message.durationSeconds,
            isRead: message.isRead,
          );

          updatedMessages.add(updatedMessage);
          await _localStorageService.saveCaregiverMessage(updatedMessage);
          messagesChanged = true;
        } else {
          updatedMessages.add(message);
        }
      }

      if (messagesChanged) {
        _messages = updatedMessages;
      }

      notifyListeners();
      return caregiver;
    } catch (e, stackTrace) {
      _handleError('Failed to update caregiver', e, stackTrace);
      return null;
    }
  }

  /// Deletes a caregiver.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> deleteCaregiver(String caregiverId) async {
    try {
      _errorMessage = null;

      // Find the caregiver
      final index = _caregivers.indexWhere((c) => c.id == caregiverId);
      if (index == -1) {
        _loggingService.warning('Attempted to delete non-existent caregiver: $caregiverId');
        return false;
      }

      // Check if there are messages with this caregiver
      final hasMessages = _messages.any((message) => message.sender.id == caregiverId);
      if (hasMessages) {
        throw StorageException(
            code: 'CAREGIVER_HAS_MESSAGES',
            message: 'This caregiver has associated messages. Please delete all messages first.'
        );
      }

      // Remove the caregiver
      final caregiver = _caregivers.removeAt(index);

      // No storage method yet - will be implemented in future version
      _loggingService.info('Deleted caregiver: ${caregiver.name}');

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Failed to delete caregiver', e, stackTrace);
      return false;
    }
  }

  /// Returns all messages for a specific caregiver.
  List<CaregiverMessage> getMessagesForCaregiver(String caregiverId) {
    return _messages
        .where((message) => message.sender.id == caregiverId)
        .toList();
  }

  /// Helper method to save an audio file to the app's directory
  Future<File> _saveAudioFile(File sourceFile) async {
    try {
      // Generate a unique filename
      final filename = '${DateTime.now().millisecondsSinceEpoch}${AppConstants.recordingFileExtension}';

      // Get the app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();

      // Get the path to save the file
      final saveDir = Directory('${appDocDir.path}/$_caregiverDirectoryName/audio');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Copy the file to our directory
      final destinationPath = '${saveDir.path}/$filename';
      final savedFile = await sourceFile.copy(destinationPath);

      return savedFile;
    } catch (e) {
      _loggingService.error('Failed to save audio file', e);
      throw StorageException(
          code: 'SAVE_AUDIO_FAILED',
          message: 'Failed to save audio file. Please try again.'
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