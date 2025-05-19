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
  bool get hasPendingChanges => _hasPendingChanges;
  
  // Initialize sync service
  Future<void> init() async {
    final lastSyncTimeStr = await _storageService.read(key: 'last_sync_time');
    if (lastSyncTimeStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeStr);
    }
    
    // Check for pending changes flag
    final hasPendingChangesStr = await _storageService.read(key: 'pending_changes');
    if (hasPendingChangesStr != null && hasPendingChangesStr == 'true') {
      _hasPendingChanges = true;
      _status = SyncStatus.pendingChanges;
      notifyListeners();
    }
    
    // Start auto sync timer (every 30 seconds)
    _startAutoSync();
  }
  
  void _startAutoSync() {
    // Cancel existing timer if any
    _syncTimer?.cancel();
    
    // Create a new timer that runs every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Check if there are pending changes or if we need to download updates
      if (_hasPendingChanges) {
        await syncWithDrive();
      } else {
        // Check for updates from other instances
        await checkForUpdates();
      }
    });
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // Mark that changes are pending
  Future<void> markChangesAsPending() async {
    _hasPendingChanges = true;
    _lastChangeTime = DateTime.now();
    _status = SyncStatus.pendingChanges;
    
    // Store pending changes flag
    await _storageService.write(key: 'pending_changes', value: 'true');
    await _storageService.write(
      key: 'last_change_time',
      value: _lastChangeTime!.toIso8601String(),
    );
    
    notifyListeners();
  }
  
  // Clear pending changes flag
  Future<void> clearPendingChanges() async {
    _hasPendingChanges = false;
    if (_status == SyncStatus.pendingChanges) {
      _status = SyncStatus.idle;
    }
    
    // Clear pending changes flag
    await _storageService.delete(key: 'pending_changes');
    
    notifyListeners();
  }
  
  // Check for updates from other instances
  Future<bool> checkForUpdates() async {
    if (_syncInProgress) {
      return false;
    }
    
    try {
      // Get last remote sync time
      final remoteSyncTimeStr = await _driveService.getFileModifiedTime(dbFileName);
      
      if (remoteSyncTimeStr != null) {
        final remoteSyncTime = DateTime.parse(remoteSyncTimeStr);
        
        // If remote file is newer than our last sync, download it
        if (_lastSyncTime == null || remoteSyncTime.isAfter(_lastSyncTime!)) {
          // But only if we don't have pending changes
          if (!_hasPendingChanges) {
            return await downloadFromDrive();
          } else {
            // We have both local changes and remote changes - need to handle conflict
            debugPrint('Sync conflict detected: both local and remote changes exist');
            // For now, prioritize local changes
            return await syncWithDrive();
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return false;
    }
  }
  
  // Sync database with Google Drive
  Future<bool> syncWithDrive() async {
    if (_syncInProgress) {
      return false;
    }
    
    _syncInProgress = true;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();
    
    try {
      // Get database file
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }
      
      // Check if drive is busy (optional - depends on your DriveService implementation)
      int retryCount = 0;
      bool success = false;
      
      while (retryCount < 3 && !success) {
        // Upload to Drive
        success = await _driveService.uploadFile(
          dbFile.path,
          dbFileName,
          'application/octet-stream',
        );
        
        if (!success) {
          // Wait before retry
          await Future.delayed(const Duration(seconds: 2));
          retryCount++;
        }
      }
      
      if (success) {
        _status = SyncStatus.success;
        _lastSyncTime = DateTime.now();
        await _storageService.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        
        // Clear pending changes flag
        await clearPendingChanges();
      } else {
        _status = SyncStatus.error;
        _lastError = 'Failed to upload file to Drive after multiple attempts';
      }
      
      notifyListeners();
      _syncInProgress = false;
      return success;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      _syncInProgress = false;
      return false;
    }
  }
  
  // Download database from Google Drive
  Future<bool> downloadFromDrive() async {
    if (_syncInProgress) {
      return false;
    }
    
    // Don't download if we have pending changes
    if (_hasPendingChanges) {
      debugPrint('Skipping download because there are pending local changes');
      return false;
    }
    
    _syncInProgress = true;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();
    
    try {
      // Get database file path
      final dbFile = await _getDatabaseFile();
      
      // Download from Drive
      final success = await _driveService.downloadFile(
        dbFileName,
        dbFile.path,
      );
      
      if (success) {
        _status = SyncStatus.success;
        _lastSyncTime = DateTime.now();
        await _storageService.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
      } else {
        _status = SyncStatus.error;
        _lastError = 'Failed to download file from Drive';
      }
      
      notifyListeners();
      _syncInProgress = false;
      return success;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      _syncInProgress = false;
      return false;
    }
  }
  
  // Sync after changes
  Future<bool> syncAfterChanges() async {
    // Mark that we have pending changes
    await markChangesAsPending();
    
    // Try to sync immediately
    return await syncWithDrive();
  }
  
  // Get database file
  Future<File> _getDatabaseFile() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, dbFileName);
    return File(path);
  }
}