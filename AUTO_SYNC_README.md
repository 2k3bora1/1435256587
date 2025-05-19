# Auto Sync Implementation for Chit Fund App

This document explains the automatic synchronization feature implemented in the Chit Fund Flutter application.

## Overview

The auto sync feature ensures that:
1. Changes made in the app are automatically synchronized with Google Drive every 30 seconds
2. The app shows a visual indicator when there are pending changes
3. The app checks for updates from other instances
4. Data is not lost when the drive is busy or when there are conflicts

## Key Components

### 1. Enhanced SyncService

The `SyncService` class has been enhanced with the following features:

- **Automatic Periodic Sync**: A timer runs every 30 seconds to check for and sync pending changes
- **Pending Changes Tracking**: The service tracks when changes are made to the database
- **Conflict Resolution**: When both local and remote changes exist, local changes are prioritized
- **Retry Mechanism**: If Google Drive is busy, the service will retry the upload up to 3 times
- **Visual Indicators**: The service provides status updates through the UI

### 2. New SyncStatus States

Added a new status `pendingChanges` to indicate when there are local changes that need to be synced.

### 3. File Modification Time Tracking

The `DriveService` now includes a method to check the last modification time of files in Google Drive, which helps detect changes made by other instances of the app.

## How It Works

1. **Initialization**:
   - When the app starts, it initializes the `SyncService` and starts a timer
   - It checks for any pending changes from previous sessions

2. **Automatic Sync Process**:
   - Every 30 seconds, the timer triggers a check:
     - If there are pending local changes, it attempts to upload to Drive
     - If there are no pending changes, it checks for remote updates

3. **When Changes Are Made**:
   - When data is modified, the `syncAfterChanges()` method is called
   - This marks changes as pending and attempts an immediate sync
   - If the sync fails, the changes remain marked as pending for the next cycle

4. **Visual Indicators**:
   - A red dot appears on the sync button when there are pending changes
   - The dashboard shows a "Pending changes" message in red
   - A progress indicator appears during active synchronization

5. **Conflict Handling**:
   - If both local and remote changes exist, local changes are prioritized
   - This ensures no data is lost, though a more sophisticated merge strategy could be implemented in the future

## User Experience

Users will notice:
- A red indicator when changes are pending
- Automatic synchronization without manual intervention
- Improved reliability when working across multiple devices
- No data loss when the network is temporarily unavailable

## Technical Implementation Details

1. **Timer Management**:
   ```dart
   _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
     // Sync logic here
   });
   ```

2. **Pending Changes Tracking**:
   ```dart
   Future<void> markChangesAsPending() async {
     _hasPendingChanges = true;
     _status = SyncStatus.pendingChanges;
     await _storageService.write(key: 'pending_changes', value: 'true');
     notifyListeners();
   }
   ```

3. **Retry Mechanism**:
   ```dart
   int retryCount = 0;
   bool success = false;
   
   while (retryCount < 3 && !success) {
     success = await _driveService.uploadFile(...);
     if (!success) {
       await Future.delayed(const Duration(seconds: 2));
       retryCount++;
     }
   }
   ```

## Limitations and Future Improvements

1. **Conflict Resolution**: Currently prioritizes local changes. A more sophisticated merge strategy could be implemented.
2. **Battery Usage**: The 30-second timer might impact battery life on mobile devices. Consider adaptive timing based on app usage.
3. **Network Awareness**: The sync could be more network-aware, pausing when on metered connections or low battery.
4. **Sync Queue**: Implement a queue system for changes to ensure they're synced in the correct order.

## Conclusion

This auto sync implementation ensures that data is synchronized across devices with minimal user intervention, improving the reliability and user experience of the Chit Fund application.