import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

/// A platform-aware storage service that uses a file-based approach
/// to avoid dependency issues with flutter_secure_storage
class StorageService {
  static final StorageService _instance = StorageService._internal();
  
  factory StorageService() => _instance;
  
  StorageService._internal();
  
  // In-memory cache for all platforms
  final Map<String, String> _cache = {};
  bool _cacheLoaded = false;
  
  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        data.forEach((key, value) {
          _cache[key] = value.toString();
        });
      }
      _cacheLoaded = true;
    } catch (e) {
      debugPrint('Error loading storage cache: $e');
      _cacheLoaded = true; // Mark as loaded even on error to prevent repeated attempts
    }
  }
  
  Future<File> _getStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/secure_storage.json');
  }
  
  Future<void> _saveCache() async {
    try {
      final file = await _getStorageFile();
      await file.writeAsString(json.encode(_cache));
    } catch (e) {
      debugPrint('Error saving storage cache: $e');
    }
  }
  
  Future<void> write({required String key, required String value}) async {
    await _ensureCacheLoaded();
    _cache[key] = value;
    await _saveCache();
  }
  
  Future<String?> read({required String key}) async {
    await _ensureCacheLoaded();
    return _cache[key];
  }
  
  Future<void> delete({required String key}) async {
    await _ensureCacheLoaded();
    _cache.remove(key);
    await _saveCache();
  }
  
  Future<void> deleteAll() async {
    _cache.clear();
    await _saveCache();
  }
}