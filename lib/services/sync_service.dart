import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/services/drive_service.dart';
import 'package:chit_fund_flutter/services/storage_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  pendingChanges,
}

class SyncService with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final DriveService _driveService = DriveService();
  final StorageService _storageService = StorageService();
  
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  DateTime? _lastChangeTime;
  Timer? _syncTimer;
  bool _hasPendingChanges = false;
  bool _syncInProgress = false;
  
  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Initialize sync service
  Future<void> init() async {
    final lastSyncTimeStr = await _storageService.read(key: 'last_sync_time');
    if (lastSyncTimeStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeStr);
    }
  }
  
  // Sync on startup
  Future<bool> syncOnStartup() async {
    _setStatus(SyncStatus.syncing);
    
    try {
      final localDbPath = await _dbService.getDatabasePath();
      
      // Check if local database exists
      final localDbFile = File(localDbPath);
      final localDbExists = await localDbFile.exists();
      
      if (!localDbExists) {
        // If local DB doesn't exist, try to download from Drive
        debugPrint('Local database not found. Attempting to download from Drive.');
        final downloadedFileId = await _driveService.downloadDatabase(localDbPath, driveDbName);
        
        if (downloadedFileId == null) {
          // No database on Drive either, create a new one
          debugPrint('No database found on Drive. Creating a new local database.');
          await _dbService.database; // This will create a new database
          
          // Upload the new database to Drive
          await _driveService.uploadDatabase(localDbPath, driveDbName);
        }
      } else {
        // Local DB exists, check if Drive has a newer version
        final driveFileId = await _driveService.downloadDatabase(localDbPath, driveDbName);
        
        if (driveFileId != null) {
          debugPrint('Downloaded database from Drive.');
        } else {
          // No database on Drive or error downloading, upload local
          debugPrint('No database found on Drive or error downloading. Uploading local database.');
          await _driveService.uploadDatabase(localDbPath, driveDbName);
        }
      }
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _storageService.write(key: 'last_sync_time', value: _lastSyncTime!.toIso8601String());
      
      _setStatus(SyncStatus.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      debugPrint('Error during sync on startup: $e');
      return false;
    }
  }
  
  // Sync after changes
  Future<bool> syncAfterChanges() async {
    _setStatus(SyncStatus.syncing);
    
    try {
      final localDbPath = await _dbService.getDatabasePath();
      
      // Upload database to Drive
      final driveFileId = _driveService.driveFileId;
      final uploadedFileId = await _driveService.uploadDatabase(
        localDbPath, 
        driveDbName,
        existingFileId: driveFileId,
      );
      
      if (uploadedFileId == null) {
        _lastError = 'Failed to upload database to Drive';
        _setStatus(SyncStatus.error);
        return false;
      }
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _storageService.write(key: 'last_sync_time', value: _lastSyncTime!.toIso8601String());
      
      _setStatus(SyncStatus.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      debugPrint('Error during sync after changes: $e');
      return false;
    }
  }
  
  // Force download from Drive
  Future<bool> forceDownloadFromDrive() async {
    _setStatus(SyncStatus.syncing);
    
    try {
      final localDbPath = await _dbService.getDatabasePath();
      
      // Close the current database connection
      await _dbService.closeDatabase();
      
      // Download database from Drive
      final downloadedFileId = await _driveService.downloadDatabase(localDbPath, driveDbName);
      
      if (downloadedFileId == null) {
        _lastError = 'Failed to download database from Drive';
        _setStatus(SyncStatus.error);
        return false;
      }
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _storageService.write(key: 'last_sync_time', value: _lastSyncTime!.toIso8601String());
      
      _setStatus(SyncStatus.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      debugPrint('Error during force download: $e');
      return false;
    }
  }
  
  // Force upload to Drive
  Future<bool> forceUploadToDrive() async {
    _setStatus(SyncStatus.syncing);
    
    try {
      final localDbPath = await _dbService.getDatabasePath();
      
      // Upload database to Drive
      final uploadedFileId = await _driveService.uploadDatabase(
        localDbPath, 
        driveDbName,
      );
      
      if (uploadedFileId == null) {
        _lastError = 'Failed to upload database to Drive';
        _setStatus(SyncStatus.error);
        return false;
      }
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _storageService.write(key: 'last_sync_time', value: _lastSyncTime!.toIso8601String());
      
      _setStatus(SyncStatus.success);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      debugPrint('Error during force upload: $e');
      return false;
    }
  }
  
  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }
}