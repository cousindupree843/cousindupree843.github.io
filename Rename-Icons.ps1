# Rename-Icons.ps1
# Rename icon files to match atlas JSON naming convention
param(
    [Parameter(Mandatory=$true)]
    [string]$ImageDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$JsonPath
)

# Read and parse JSON
try {
    $config = Get-Content $JsonPath | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON file: $JsonPath"
    exit 1
}

# Validate JSON structure
if (-not $config.frames) {
    Write-Error "Invalid JSON structure: missing 'frames' array"
    exit 1
}

# Use wildcard in path for -Include to work
$imageFiles = Get-ChildItem -Path (Join-Path $ImageDirectory '*') -File `
    -Include *.png,*.jpg,*.jpeg,*.gif,*.bmp

Write-Host "Found $($imageFiles.Count) image files"
Write-Host "JSON contains $($config.frames.Count) frame definitions"

# Use frames array for renaming
$frames = $config.frames

$renamedCount = 0
$skippedCount = 0

for ($i = 0; $i -lt [Math]::Min($imageFiles.Count, $frames.Count); $i++) {
    $file = $imageFiles[$i]
    $targetName = "$($frames[$i].name)$($file.Extension)"
    $targetPath = Join-Path $file.DirectoryName $targetName

    # Only rename if the name is different
    if ($file.Name -ne $targetName) {
        # If a file with the target name exists, remove it to avoid conflicts
        if (Test-Path $targetPath) {
            Remove-Item $targetPath -Force
        }
        Write-Host "Renaming: $($file.Name) -> $targetName"
        try {
            Rename-Item -Path $file.FullName -NewName $targetName
            $renamedCount++
        } catch {
            Write-Error "Failed to rename $($file.Name): $($_.Exception.Message)"
        }
    } else {
        Write-Host "Skipping: $($file.Name) (already correct name)"
        $skippedCount++
    }
}

Write-Host "Renaming complete"
Write-Host "Files renamed: $renamedCount"
Write-Host "Files skipped: $skippedCount"
Write-Host "Total files processed: $($imageFiles.Count)"
