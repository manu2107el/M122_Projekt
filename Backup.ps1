# Passen Sie die unteren Zeilen nach Ihren Bedürfnissen an.
$sourcePath = "C:\pa\files"
$backupPath = "C:\pa\backups"
# Passen Sie die oberen Zeilen nach Ihren Bedürfnissen an.

$backupFileName = "Backup_" + (Get-Date -Format "yyyyMMdd") + ".zip"
$backupFilePath = Join-Path $backupPath $backupFileName
$latestBackup = Get-ChildItem $backupPath | Sort-Object LastWriteTime -Descending | Select-Object -First 1

Function doBackup() {
    $filesToBackup | Compress-Archive -DestinationPath $backupFilePath -Update
    Write-Host "Backup erfolgreich erstellt: $backupFilePath"
}

Function getFilesToBackup() {
    if ($latestBackup -eq $null) {
        # Es wurde noch kein vorheriges Backup gefunden, daher werden alle Dateien gesichert
        $filesToBackup = Get-ChildItem $sourcePath -Recurse
    } else {
        # Es wurde ein vorheriges Backup gefunden, daher werden nur neue oder geänderte Dateien gesichert
        $lastBackupTime = $latestBackup.LastWriteTime
        $filesToBackup = Get-ChildItem $sourcePath -Recurse | Where-Object { $_.LastWriteTime -gt $lastBackupTime }
    }

    if ($filesToBackup.Count -eq 0) {
        Write-Host "Keine neuen oder geänderten Dateien zum Sichern gefunden."
        exit
    }
    
    return $filesToBackup
}

$filesToBackup = getFilesToBackup
doBackup
