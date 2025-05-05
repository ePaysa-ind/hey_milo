/*
file path: hey_milo\lib\models\caregiver_message_model.dart
Caregiver Message Model for the Milo App
Represents a message from a caregiver to the user.
Author: Milo App Development Team
Last Updated: May 4, 2025
*/

import 'dart:io';

/*Enum representing the type of caregiver message*/
enum CaregiverMessageType {
  text,
  audio,
}

/// Extension for CaregiverMessageType enum to provide additional functionality
extension CaregiverMessageTypeExtension on CaregiverMessageType {
  /// Get a string representation of the message type
  String get displayName {
    switch (this) {
      case CaregiverMessageType.text:
        return 'Text';
      case CaregiverMessageType.audio:
        return 'Voice';
    }
  }

  /// Convert string to CaregiverMessageType
  static CaregiverMessageType fromString(String value) {
    return CaregiverMessageType.values.firstWhere(
          (type) => type.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => CaregiverMessageType.text,
    );
  }
}

/// Represents a caregiver entity
class Caregiver {
  /// Unique identifier for the caregiver
  final String id;

  /// Display name of the caregiver
  final String name;

  /// Optional relationship to the user (e.g., "Son", "Daughter", "Nurse")
  final String? relationship;

  /// Create a new Caregiver object
  ///
  /// @param id Unique identifier for the caregiver
  /// @param name Display name of the caregiver
  /// @param relationship Optional relationship to the user
  Caregiver({
    required this.id,
    required this.name,
    this.relationship,
  });

  /// Create a Caregiver object from a JSON map
  ///
  /// @param json The JSON map to convert
  /// @return A new Caregiver object
  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String?,
    );
  }

  /// Convert the Caregiver object to a JSON map
  ///
  /// @return A JSON map representing the Caregiver
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
    };
  }

  /// Create a copy of this Caregiver with updated fields
  ///
  /// @param name New name for the caregiver
  /// @param relationship New relationship
  /// @return A new Caregiver object with updated fields
  Caregiver copyWith({
    String? name,
    String? relationship,
  }) {
    return Caregiver(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Caregiver &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return relationship != null && relationship!.isNotEmpty
        ? 'Caregiver{name: $name, relationship: $relationship}'
        : 'Caregiver{name: $name}';
  }
}

/// Represents a message from a caregiver to the user
class CaregiverMessage {
  /// Unique identifier for the message
  final String id;

  /// Information about the caregiver who sent the message
  final Caregiver sender;

  /// When the message was received
  final DateTime timestamp;

  /// Type of message (text or audio)
  final CaregiverMessageType type;

  /// Content of the message (text content or file path)
  final String content;

  /// For audio messages, the duration in seconds
  final int? durationSeconds;

  /// Whether the message has been viewed/listened to
  final bool isRead;

  /// Create a new CaregiverMessage object
  ///
  /// @param id Unique identifier for the message
  /// @param sender Information about the caregiver who sent the message
  /// @param timestamp When the message was received
  /// @param type Type of message (text or audio)
  /// @param content Content of the message (text content or file path)
  /// @param durationSeconds For audio messages, the duration in seconds
  /// @param isRead Whether the message has been viewed/listened to
  CaregiverMessage({
    required this.id,
    required this.sender,
    required this.timestamp,
    required this.type,
    required this.content,
    this.durationSeconds,
    this.isRead = false,
  });

  /// Create a CaregiverMessage object from a JSON map
  ///
  /// @param json The JSON map to convert
  /// @return A new CaregiverMessage object
  factory CaregiverMessage.fromJson(Map<String, dynamic> json) {
    return CaregiverMessage(
      id: json['id'] as String,
      sender: Caregiver.fromJson(json['sender'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: CaregiverMessageTypeExtension.fromString(json['type'] as String),
      content: json['content'] as String,
      durationSeconds: json['durationSeconds'] as int?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Convert the CaregiverMessage object to a JSON map
  ///
  /// @return A JSON map representing the CaregiverMessage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'content': content,
      'durationSeconds': durationSeconds,
      'isRead': isRead,
    };
  }

  /// Create a text message
  ///
  /// @param sender The caregiver who sent the message
  /// @param text The text content
  /// @param id Optional identifier (generated if not provided)
  /// @param timestamp When the message was received (defaults to now)
  /// @return A new CaregiverMessage object
  factory CaregiverMessage.text({
    required Caregiver sender,
    required String text,
    String? id,
    DateTime? timestamp,
  }) {
    return CaregiverMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender,
      timestamp: timestamp ?? DateTime.now(),
      type: CaregiverMessageType.text,
      content: text,
      isRead: false,
    );
  }

  /// Create an audio message
  ///
  /// @param sender The caregiver who sent the message
  /// @param filePath Path to the audio file
  /// @param durationSeconds Duration of the audio in seconds
  /// @param id Optional identifier (generated if not provided)
  /// @param timestamp When the message was received (defaults to now)
  /// @return A new CaregiverMessage object
  factory CaregiverMessage.audio({
    required Caregiver sender,
    required String filePath,
    required int durationSeconds,
    String? id,
    DateTime? timestamp,
  }) {
    return CaregiverMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender,
      timestamp: timestamp ?? DateTime.now(),
      type: CaregiverMessageType.audio,
      content: filePath,
      durationSeconds: durationSeconds,
      isRead: false,
    );
  }

  /// Create a copy of this CaregiverMessage with updated fields
  ///
  /// @param isRead Updated read status
  /// @return A new CaregiverMessage object with updated fields
  CaregiverMessage copyWith({
    bool? isRead,
  }) {
    return CaregiverMessage(
      id: id,
      sender: sender,
      timestamp: timestamp,
      type: type,
      content: content,
      durationSeconds: durationSeconds,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Mark the message as read
  ///
  /// @return A new CaregiverMessage object with isRead set to true
  CaregiverMessage markAsRead() {
    return copyWith(isRead: true);
  }

  /// Check if an audio message file exists on the device
  ///
  /// @return Future-bool True if the file exists (or if not an audio message)
  Future<bool> exists() async {
    if (type != CaregiverMessageType.audio) {
      return true; // Text messages don't have files to check
    }

    final file = File(content);
    return await file.exists();
  }

  /// Format the audio duration as a string (MM:SS)
  ///
  /// @return String Formatted duration or empty string if not an audio message
  String get formattedDuration {
    if (type != CaregiverMessageType.audio || durationSeconds == null) {
      return '';
    }

    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get the content to display
  ///
  /// For text messages, returns the text content.
  /// For audio messages, returns a description.
  ///
  /// @return String The content to display
  String get displayContent {
    switch (type) {
      case CaregiverMessageType.text:
        return content;
      case CaregiverMessageType.audio:
        return 'Voice message ($formattedDuration)';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CaregiverMessage &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CaregiverMessage{id: $id, sender: ${sender.name}, type: ${type.displayName}, timestamp: $timestamp}';
  }
}