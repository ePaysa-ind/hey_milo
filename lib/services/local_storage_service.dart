import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/exceptions.dart';
import '../models/memory_model.dart';
import '../models/caregiver_message_model.dart';
import '../services/logging_service.dart';
import 'package:get_it/get_it.dart';

class LocalStorageService {
  final LoggingService _logger = GetIt.instance<LoggingService>();
  final Uuid _uuid = const Uuid();

  late final Directory _appDocumentsDir;
  late final Directory _memoriesDir;
  late final Directory _caregiverMessagesDir;

  late final String _memoryRecordingsPath;
  late final String _memoryMetadataPath;
  late final String _caregiverMessagesPath;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('LocalStorageService: Initializing local storage directories');
      _appDocumentsDir = await getApplicationDocumentsDirectory();

      _memoriesDir = Directory(path.join(_appDocumentsDir.path, 'memories'));
      _caregiverMessagesDir = Directory(path.join(_appDocumentsDir.path, 'caregiver_messages'));

      _memoryRecordingsPath = path.join(_memoriesDir.path, 'recordings');
      _memoryMetadataPath = path.join(_memoriesDir.path, 'metadata');
      _caregiverMessagesPath = path.join(_caregiverMessagesDir.path, 'messages');

      await _createDirectoryIfNotExists(Directory(_memoryRecordingsPath));
      await _createDirectoryIfNotExists(Directory(_memoryMetadataPath));
      await _createDirectoryIfNotExists(Directory(_caregiverMessagesPath));

      _isInitialized = true;
      _logger.info('LocalStorageService: Successfully initialized local storage');
    } catch (e) {
      _logger.error('LocalStorageService: Failed to initialize local storage: $e');
      throw StorageException(message: 'Failed to initialize local storage: $e', code: 'INIT_FAILURE');
    }
  }

  Future<void> _createDirectoryIfNotExists(Directory directory) async {
    if (!await directory.exists()) {
      _logger.info('Creating directory: ${directory.path}');
      await directory.create(recursive: true);
    }
  }

  /// Returns the app documents directory.
  ///
  /// This is used by services that need access to this directory.
  Future<Directory> getAppDocumentsDirectory() async {
    if (!_isInitialized) await initialize();
    return _appDocumentsDir;
  }

  Future<Memory> saveMemoryRecording(Memory memory, File audioFile) async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final String memoryId = memory.id.isEmpty ? _uuid.v4() : memory.id;
      final String audioFileName = '$memoryId.m4a';
      final String metadataFileName = '$memoryId.json';
      final String audioFilePath = path.join(_memoryRecordingsPath, audioFileName);
      final String metadataFilePath = path.join(_memoryMetadataPath, metadataFileName);

      final File savedAudioFile = await audioFile.copy(audioFilePath);

      final Memory memoryToSave = Memory(
        id: memoryId,
        filePath: savedAudioFile.path,
        durationSeconds: memory.durationSeconds,
        fileSizeBytes: memory.fileSizeBytes,
        timestamp: memory.timestamp,
        cloudBackupPath: memory.cloudBackupPath,
        isMarkedForDeletion: memory.isMarkedForDeletion,
      );

      final File metadataFile = File(metadataFilePath);
      await metadataFile.writeAsString(json.encode(memoryToSave.toJson()));
      return memoryToSave;
    } catch (e) {
      throw StorageException(message: 'Failed to save memory recording: $e', code: 'SAVE_MEMORY_FAILED');
    }
  }

  Future<List<Memory>> getAllMemories() async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final Directory metadataDir = Directory(_memoryMetadataPath);
      if (!await metadataDir.exists()) return [];

      final List<Memory> memories = [];
      await for (final entity in metadataDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final String contents = await entity.readAsString();
            final Map<String, dynamic> jsonData = json.decode(contents);
            memories.add(Memory.fromJson(jsonData));
          } catch (_) {}
        }
      }

      memories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return memories;
    } catch (e) {
      throw StorageException(message: 'Failed to retrieve memories: $e', code: 'GET_MEMORIES_FAILED');
    }
  }

  Future<void> deleteMemory(String memoryId) async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final audioFile = File(path.join(_memoryRecordingsPath, '$memoryId.m4a'));
      final metadataFile = File(path.join(_memoryMetadataPath, '$memoryId.json'));

      await Future.wait([
        if (await audioFile.exists()) audioFile.delete(),
        if (await metadataFile.exists()) metadataFile.delete(),
      ]);
    } catch (e) {
      throw StorageException(message: 'Failed to delete memory: $e', code: 'DELETE_MEMORY_FAILED');
    }
  }

  Future<CaregiverMessage> saveCaregiverMessage(CaregiverMessage message) async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final String messageId = message.id.isEmpty ? _uuid.v4() : message.id;

      final messageToSave = CaregiverMessage(
        id: messageId,
        sender: message.sender,
        timestamp: message.timestamp,
        type: message.type,
        content: message.content,
        durationSeconds: message.durationSeconds,
        isRead: message.isRead,
      );

      final File messageFile = File(path.join(_caregiverMessagesPath, '$messageId.json'));
      await messageFile.writeAsString(json.encode(messageToSave.toJson()));
      return messageToSave;
    } catch (e) {
      throw StorageException(message: 'Failed to save caregiver message: $e', code: 'SAVE_CAREGIVER_MSG_FAILED');
    }
  }

  Future<List<CaregiverMessage>> getAllCaregiverMessages() async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final dir = Directory(_caregiverMessagesPath);
      if (!await dir.exists()) return [];

      final messages = <CaregiverMessage>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final String content = await entity.readAsString();
            messages.add(CaregiverMessage.fromJson(json.decode(content)));
          } catch (_) {}
        }
      }

      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    } catch (e) {
      throw StorageException(message: 'Failed to retrieve caregiver messages: $e', code: 'GET_CAREGIVER_MESSAGES_FAILED');
    }
  }

  Future<void> deleteCaregiverMessage(String messageId) async {
    if (!_isInitialized) throw StorageException(message: 'Service not initialized', code: 'NOT_INITIALIZED');

    try {
      final messageFile = File(path.join(_caregiverMessagesPath, '$messageId.json'));
      if (await messageFile.exists()) {
        await messageFile.delete();
      }
    } catch (e) {
      throw StorageException(message: 'Failed to delete caregiver message: $e', code: 'DELETE_CAREGIVER_MSG_FAILED');
    }
  }

  /// Reads a file as a string.
  ///
  /// [filePath] The path to the file.
  /// Returns the file contents as a string.
  Future<String> readFile(String filePath) async {
    if (!_isInitialized) await initialize();

    try {
      final file = File(path.join(_appDocumentsDir.path, filePath));
      if (!await file.exists()) {
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      throw StorageException(message: 'Failed to read file: $e', code: 'READ_FILE_FAILED');
    }
  }

  /// Writes a string to a file.
  ///
  /// [filePath] The path to the file.
  /// [content] The content to write.
  Future<void> writeFile(String filePath, String content) async {
    if (!_isInitialized) await initialize();

    try {
      final file = File(path.join(_appDocumentsDir.path, filePath));

      // Create parent directories if they don't exist
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await file.writeAsString(content);
    } catch (e) {
      throw StorageException(message: 'Failed to write file: $e', code: 'WRITE_FILE_FAILED');
    }
  }
}