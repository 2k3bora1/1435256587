import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:chit_fund_flutter/config/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

class DriveService {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  
  DriveService._internal() {
    _loadDriveFileId();
  }
  
  drive.DriveApi? _driveApi;
  String? _driveFileId;
  
  static const String _driveFileIdKey = 'drive_file_id';
  
  String? get driveFileId => _driveFileId;
  
  // Load the Drive file ID from persistent storage
  Future<void> _loadDriveFileId() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/drive_file_id.txt');
      
      if (await file.exists()) {
        _driveFileId = await file.readAsString();
        debugPrint('Loaded Drive file ID from storage: $_driveFileId');
      }
    } catch (e) {
      debugPrint('Error loading Drive file ID: $e');
    }
  }
  
  // Save the Drive file ID to persistent storage
  Future<void> _saveDriveFileId(String? fileId) async {
    try {
      if (fileId == null) return;
      
      _driveFileId = fileId;
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/drive_file_id.txt');
      
      await file.writeAsString(fileId);
      debugPrint('Saved Drive file ID to storage: $fileId');
    } catch (e) {
      debugPrint('Error saving Drive file ID: $e');
    }
  }
  
  Future<drive.DriveApi?> get driveApi async {
    if (_driveApi != null) return _driveApi;
    _driveApi = await _initDriveApi();
    return _driveApi;
  }
  
  Future<drive.DriveApi?> _initDriveApi() async {
    try {
      // Load the appropriate credentials file based on platform
      String credentialsPath;
      if (Platform.isWindows) {
        credentialsPath = 'assets/credentials_windows.json';
      } else if (Platform.isAndroid) {
        credentialsPath = 'assets/credentials_android.json';
      } else {
        debugPrint('Unsupported platform for Google Drive integration');
        return null;
      }
      
      debugPrint('Loading credentials from $credentialsPath');
      
      // Load and parse the credentials file
      try {
        final String credentialsJson = await rootBundle.loadString(credentialsPath);
        debugPrint('Credentials loaded successfully');
        
        // Different authentication methods based on platform
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile platforms use Google Sign-In
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: driveScopes,
          );
          
          final GoogleSignInAccount? account = await googleSignIn.signIn();
          if (account == null) {
            debugPrint('Google Sign-In failed: User canceled');
            return null;
          }
          
          final Map<String, String> authHeaders = await account.authHeaders;
          
          final authenticatedClient = _AuthenticatedClient(
            http.Client(),
            authHeaders,
          );
          
          final api = drive.DriveApi(authenticatedClient);
          debugPrint('Google Drive API initialized successfully (mobile)');
          return api;
        } else {
          // Desktop platforms use OAuth2 with authorization code flow
          final Map<String, dynamic> credentials = json.decode(credentialsJson);
          
          // Extract clientId and secret from the credentials file
          final clientId = ClientId(
            credentials['installed']['client_id'],
            credentials['installed']['client_secret'],
          );
          
          try {
            // Authenticate with OAuth2
            final client = await _authenticateWithOAuth2(clientId, driveScopes);
            if (client == null) {
              debugPrint('OAuth2 authentication failed');
              return null;
            }
            
            final api = drive.DriveApi(client);
            debugPrint('Google Drive API initialized successfully (desktop)');
            return api;
          } catch (e) {
            debugPrint('Error during OAuth2 authentication: $e');
            return null;
          }
        }
      } catch (e) {
        debugPrint('Error loading credentials file: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Error initializing Google Drive API: $e');
      return null;
    }
  }
  
  Future<String?> uploadDatabase(String localPath, String driveName, {String? existingFileId}) async {
    final api = await driveApi;
    if (api == null) {
      debugPrint('Drive API not available. Skipping upload.');
      return null;
    }
    
    if (!File(localPath).existsSync()) {
      debugPrint('Local database file "$localPath" not found. Skipping upload.');
      return existingFileId;
    }
    
    try {
      final fileContent = File(localPath).readAsBytesSync();
      
      // If we have an existing file ID from a previous operation, use it
      if (existingFileId != null) {
        return _updateExistingFile(api, existingFileId, driveName, fileContent);
      }
      
      // If we have a stored file ID from a previous session, use it
      if (_driveFileId != null) {
        return _updateExistingFile(api, _driveFileId!, driveName, fileContent);
      }
      
      // Search for an existing file with the same name
      debugPrint('Searching for existing "$driveName" in Google Drive...');
      final fileList = await api.files.list(
        q: "name='$driveName' and trashed=false",
        $fields: "files(id, name)",
      );
      
      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        // Update the existing file
        final existingFile = files.first;
        debugPrint('Found existing file "${existingFile.name}" (ID: ${existingFile.id}) in Drive.');
        return _updateExistingFile(api, existingFile.id!, driveName, fileContent);
      } else {
        // Create a new file if none exists
        debugPrint('No existing file found. Creating new file "$driveName" in Google Drive.');
        
        final driveFile = drive.File()
          ..name = driveName
          ..mimeType = 'application/x-sqlite3';
        
        final media = drive.Media(
          Stream.value(fileContent),
          fileContent.length,
          contentType: 'application/x-sqlite3',
        );
        
        final result = await api.files.create(
          driveFile,
          uploadMedia: media,
        );
        
        await _saveDriveFileId(result.id);
        debugPrint('Successfully uploaded new database file to Google Drive with ID: ${result.id}');
        return result.id;
      }
    } catch (e) {
      debugPrint('Failed to upload database file: $e');
      return existingFileId;
    }
  }
  
  Future<bool> uploadFile(String localPath, String driveName, String mimeType) async {
    final fileId = await uploadDatabase(localPath, driveName);
    return fileId != null;
  }
  
  Future<bool> downloadFile(String driveName, String localPath) async {
    final fileId = await downloadDatabase(localPath, driveName);
    return fileId != null;
  }
  
  // Get the last modified time of a file in Google Drive
  Future<String?> getFileModifiedTime(String driveName) async {
    final api = await driveApi;
    if (api == null) {
      debugPrint('Drive API not available. Cannot get file modified time.');
      return null;
    }
    
    try {
      // Search for the file
      debugPrint('Searching for "$driveName" in Google Drive to get modified time...');
      final fileList = await api.files.list(
        q: "name='$driveName' and trashed=false",
        $fields: "files(id, name, modifiedTime)",
        orderBy: "modifiedTime desc",
      );
      
      final files = fileList.files;
      if (files == null || files.isEmpty) {
        debugPrint('No existing file "$driveName" found in Drive.');
        return null;
      }
      
      final file = files.first;
      if (file.modifiedTime != null) {
        debugPrint('File "$driveName" last modified at: ${file.modifiedTime}');
        return file.modifiedTime!.toIso8601String();
      } else {
        debugPrint('File "$driveName" found but no modification time available.');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting file modified time from Drive: $e');
      return null;
    }
  }
  
  Future<http.Client?> _authenticateWithOAuth2(ClientId clientId, List<String> scopes) async {
    try {
      return await clientViaUserConsent(
        clientId,
        scopes,
        (String url) async {
          debugPrint('Please authenticate in your browser with the following URL:');
          debugPrint(url);
          
          final Uri authUri = Uri.parse(url);
          if (await canLaunchUrl(authUri)) {
            await launchUrl(authUri, mode: LaunchMode.externalApplication);
          } else {
            debugPrint('Could not launch browser for authentication');
            return;
          }
        },
      );
    } catch (e) {
      debugPrint('Error during OAuth2 authentication: $e');
      return null;
    }
  }
  
  Future<String?> _updateExistingFile(drive.DriveApi api, String fileId, String fileName, List<int> fileContent) async {
    try {
      debugPrint('Updating existing Drive file ID: $fileId');
      
      final media = drive.Media(
        Stream.value(fileContent),
        fileContent.length,
        contentType: 'application/x-sqlite3',
      );
      
      final driveFile = await api.files.update(
        drive.File()..name = fileName,
        fileId,
        uploadMedia: media,
      );
      
      await _saveDriveFileId(driveFile.id);
      debugPrint('Successfully updated database file in Google Drive with ID: ${driveFile.id}');
      return driveFile.id;
    } catch (e) {
      debugPrint('Error updating file in Google Drive: $e');
      return null;
    }
  }
  
  Future<String?> downloadDatabase(String localPath, String driveName) async {
    final api = await driveApi;
    if (api == null) {
      debugPrint('Drive API not available. Skipping download.');
      return null;
    }
    
    try {
      // Search for the file
      debugPrint('Searching for "$driveName" in Google Drive...');
      final fileList = await api.files.list(
        q: "name='$driveName' and trashed=false",
        $fields: "files(id, name, modifiedTime)",
        orderBy: "modifiedTime desc",
      );
      
      final files = fileList.files;
      if (files == null || files.isEmpty) {
        debugPrint('No existing database "$driveName" found in Drive.');
        _driveFileId = null;
        return null;
      }
      
      final fileToDownload = files.first;
      final downloadFileId = fileToDownload.id!;
      debugPrint('Found database "${fileToDownload.name}" (ID: $downloadFileId, Last Modified: ${fileToDownload.modifiedTime}) in Drive.');
      
      // Ensure directory exists
      final directory = Directory(localPath).parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      // Download the file
      debugPrint('Starting download of "$driveName" (ID: $downloadFileId) from Drive...');
      final response = await api.files.get(
        downloadFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final file = File(localPath);
      final fileStream = file.openWrite();
      
      await response.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
      
      debugPrint('Successfully downloaded "$driveName" to "$localPath".');
      await _saveDriveFileId(downloadFileId);
      return downloadFileId;
    } catch (e) {
      debugPrint('Error downloading database from Drive: $e');
      return null;
    }
  }
}

class _AuthenticatedClient extends http.BaseClient {
  final http.Client _client;
  final Map<String, String> _headers;
  
  _AuthenticatedClient(this._client, this._headers);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}