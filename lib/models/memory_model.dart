/*
File path: hey_milo\lib\models\memory_model.dart
Memory Model for the Milo App
Represents a voice memory entry in the user's journal.
Author: Milo App Development Team
Last Updated: May 4, 2025
*/


import 'dart:io';

/// Represents a voice memory recording in the user's journal
class Memory {
  /// Unique identifier for the memory
  final String id;

  /// Path to the audio file on the device
  final String filePath;

  /// When the memory was recorded
  final DateTime timestamp;

  /// Duration of the recording in seconds
  final int durationSeconds;

  /// Size of the file in bytes
  final int fileSizeBytes;

  /// Optional path to cloud backup if uploaded
  final String? cloudBackupPath;

  /// Flag indicating if this memory is marked for deletion
  final bool isMarkedForDeletion;

  /// Create a new Memory object
  ///
  /// @param id Unique identifier for the memory
  /// @param filePath Path to the audio file on the device
  /// @param timestamp When the memory was recorded
  /// @param durationSeconds Duration of the recording in seconds
  /// @param fileSizeBytes Size of the file in bytes
  /// @param cloudBackupPath Optional path to cloud backup if uploaded
  /// @param isMarkedForDeletion Flag indicating if this memory is marked for deletion
  Memory({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.cloudBackupPath,
    this.isMarkedForDeletion = false,
  });

  /// Create a Memory object from a JSON map
  ///
  /// @param json The JSON map to convert
  /// @return A new Memory object
  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: json['durationSeconds'] as int,
      fileSizeBytes: json['fileSizeBytes'] as int,
      cloudBackupPath: json['cloudBackupPath'] as String?,
      isMarkedForDeletion: json['isMarkedForDeletion'] as bool? ?? false,
    );
  }

  /// Convert the Memory object to a JSON map
  ///
  /// @return A JSON map representing the Memory
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
      'cloudBackupPath': cloudBackupPath,
      'isMarkedForDeletion': isMarkedForDeletion,
    };
  }

  /// Create a Memory object from a file
  ///
  /// @param file The audio file
  /// @param id Optional id -will be generated if not provided
  /// @param durationSeconds The duration of the recording
  /// @return Future Memory- A new Memory object
  static Future<Memory> fromFile({
    required File file,
    String? id,
    required int durationSeconds,
  }) async {
    // Get file size
    final fileSize = await file.length();

    return Memory(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: file.path,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSize,
      isMarkedForDeletion: false,
    );
  }

  /// Create a copy of this Memory with updated fields
  ///
  /// @param cloudBackupPath New cloud backup path
  /// @param isMarkedForDeletion New deletion flag
  /// @return A new Memory object with updated fields
  Memory copyWith({
    String? cloudBackupPath,
    bool? isMarkedForDeletion,
  }) {
    return Memory(
      id: id,
      filePath: filePath,
      timestamp: timestamp,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      cloudBackupPath: cloudBackupPath ?? this.cloudBackupPath,
      isMarkedForDeletion: isMarkedForDeletion ?? this.isMarkedForDeletion,
    );
  }

  /// Check if the memory is older than a specified number of days
  ///
  /// @param days Number of days to check against
  /// @return bool True if the memory is older than the specified days
  bool isOlderThan(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return timestamp.isBefore(cutoff);
  }

  /// Check if the memory exists on the device
  ///
  /// @return Future-bool True if the file exists
  Future<bool> exists() async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Check if the memory has been backed up to cloud storage
  ///
  /// @return bool True if the memory has a cloud backup path
  bool get isBackedUp => cloudBackupPath != null && cloudBackupPath!.isNotEmpty;

  /// Format the duration as a string (MM:SS)
  ///
  /// @return String Formatted duration
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get the file size in a human-readable format
  ///
  /// @return String Formatted file size
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Memory &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Memory{id: $id, timestamp: $timestamp, duration: $formattedDuration}';
  }
}