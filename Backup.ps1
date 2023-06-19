# Passen Sie die unteren Zeilen nach Ihren Bedürfnissen an.
$Source = "C:\pa\files"
$BackupDirectory = "C:\pa\backups"
# Passen Sie die oberen Zeilen nach Ihren Bedürfnissen an.

function Get-FilesToBackup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$BackupDirectory
    )

    $Source = $Source.ToLower().TrimEnd('\')
    $BackupDirectory = $BackupDirectory.ToLower().TrimEnd('\')

    # Überprüfen ob quellverzeichniss existiert
    if (-not (Test-Path -Path $Source)) {
        Write-Host "Quellverzeichniss konnte nicht gefunden werden."
        return
    }

    # Get the last backup file
    $LatestBackup = Get-ChildItem -Path $BackupDirectory | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # Check if this is an incremental backup or full backup
    if ($LatestBackup -eq $null) {
        # If it is a full backup, copy all files
        $FilesToCopy = Get-ChildItem -Path $Source -File -Recurse
    } else {
        $LastBackupTime = $LatestBackup.LastWriteTime

        # Only copy files that are new or modified since the last backup
        $FilesToCopy = Get-ChildItem -Path $Source -File -Recurse | Where-Object { $_.LastWriteTime -gt $LastBackupTime }
    }

    if ($FilesToCopy.Count -eq 0) {
        Write-Host "No changes detected since the last backup. Skipping backup."
        return
    }

    $BackupFileName = "Backup_" + (Get-Date -Format "yyyyMMdd") + ".zip"
    $BackupFilePath = Join-Path $BackupDirectory $BackupFileName

    return @{
        'FilesToCopy' = $FilesToCopy
        'BackupFilePath' = $BackupFilePath
    }
}

function Perform-Backup {
    param(
        [Parameter(Mandatory=$true)]
        [Hashtable]$BackupData
    )

    $FilesToCopy = $BackupData.FilesToCopy
    $BackupFilePath = $BackupData.BackupFilePath

    # Temporäres Verzeichniss erstellen.
    $TempBackupDir = Join-Path -Path $BackupDirectory -ChildPath "Backup"
    if (Test-Path -Path $TempBackupDir) {
        Remove-Item -Path $TempBackupDir -Recurse -Force
    }
    New-Item -Path $TempBackupDir -ItemType Directory | Out-Null

    # Dateien ins temporäre verzeichniss kopieren
    foreach ($File in $FilesToCopy) {
        $RelativePath = $File.FullName.Substring($Source.Length)
        $DstFile = Join-Path -Path $TempBackupDir -ChildPath $RelativePath

        # Sichergehen, dass das ziel verzeichniss existiert
        $DstDir = Split-Path -Path $DstFile
        if (-not (Test-Path -Path $DstDir)) {
            New-Item -Path $DstDir -ItemType Directory | Out-Null
        }

        # Dateien Kopieren
        Copy-Item -Path $File.FullName -Destination $DstFile
    }

    # Zipen
    Compress-Archive -Path $TempBackupDir -DestinationPath $BackupFilePath -Update

    Remove-Item -Path $TempBackupDir -Recurse -Force

    Write-Host "Backup erfolgreich erstellt: $BackupFilePath"
}

function Backup-Files {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$BackupDirectory
    )

    $BackupData = Get-FilesToBackup -Source $Source -BackupDirectory $BackupDirectory

    if ($BackupData -ne $null) {
        Perform-Backup -BackupData $BackupData
    }
}

Backup-Files -Source $Source -BackupDirectory $BackupDirectory
