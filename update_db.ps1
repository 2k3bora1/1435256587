 = Get-Content -Path lib\services\database_service.dart -Raw 
 =  -replace 'version: 1,', 'version: 2,' 
 =  -replace '// Example upgrade to version 2', '// Add description column to chit_funds table' 
