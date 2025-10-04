# spritesheet-rename.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ImageDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$JsonPath
)

# Read and parse JSON
$config = Get-Content $JsonPath | ConvertFrom-Json

# Get all image files in directory
$imageFiles = Get-ChildItem -Path $ImageDirectory -File `
    -Include *.png,*.jpg,*.jpeg,*.gif,*.bmp

Write-Host "Found $($imageFiles.Count) image files"

# Create lookup by index
$framesByIndex = @{}
foreach ($frame in $config.frames) {
    $framesByIndex[$frame.index] = $frame.name
}

# Rename files by index (assuming files are named 0.png, 1.png, etc.)
foreach ($file in $imageFiles) {
    # Extract index from filename
    if ($file.BaseName -match '^\d+$') {
        $index = [int]$file.BaseName
        
        if ($framesByIndex.ContainsKey($index)) {
            $newName = $framesByIndex[$index] + $file.Extension
            $newPath = Join-Path $file.DirectoryName $newName
            
            Write-Host "Renaming: $($file.Name) -> $newName"
            Rename-Item -Path $file.FullName -NewName $newName
        }
    }
}

Write-Host "Renaming complete"
