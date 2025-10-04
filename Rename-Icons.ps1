# spritesheet-rename.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ImageDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$JsonPath
)

# Read and parse JSON
$config = Get-Content $JsonPath | ConvertFrom-Json

# Use wildcard in path for -Include to work
$imageFiles = Get-ChildItem -Path (Join-Path $ImageDirectory '*') -File `
    -Include *.png,*.jpg,*.jpeg,*.gif,*.bmp

Write-Host "Found $($imageFiles.Count) image files"

# Use frames array for renaming
$frames = $config.frames

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
        Rename-Item -Path $file.FullName -NewName $targetName
    }
}

Write-Host "Renaming complete"
Write-Host "Total files processed: $($imageFiles.Count)"
