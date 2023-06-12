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

    # Check if source directory exists
    if (-not (Test-Path -Path $Source)) {
        Write-Host "Source directory does not exist."
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

    # Create a temporary backup directory
    $TempBackupDir = Join-Path -Path $BackupDirectory -ChildPath "temp_backup"
    if (Test-Path -Path $TempBackupDir) {
        Remove-Item -Path $TempBackupDir -Recurse -Force
    }
    New-Item -Path $TempBackupDir -ItemType Directory | Out-Null

    # Copy the files to the temporary backup directory
    foreach ($File in $FilesToCopy) {
        $RelativePath = $File.FullName.Substring($Source.Length)
        $DstFile = Join-Path -Path $TempBackupDir -ChildPath $RelativePath

        # Ensure the destination directory exists
        $DstDir = Split-Path -Path $DstFile
        if (-not (Test-Path -Path $DstDir)) {
            New-Item -Path $DstDir -ItemType Directory | Out-Null
        }

        # Copy the file to the destination
        Copy-Item -Path $File.FullName -Destination $DstFile
    }

    # Compress backup files
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
