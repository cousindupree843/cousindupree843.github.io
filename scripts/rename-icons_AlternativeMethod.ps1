# spritesheet-rename-by-order.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ImageDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$JsonPath
)

$config = Get-Content $JsonPath | ConvertFrom-Json
$imageFiles = Get-ChildItem -Path $ImageDirectory -File `
    -Include *.png,*.jpg,*.jpeg,*.gif,*.bmp | Sort-Object Name

Write-Host "Found $($imageFiles.Count) image files"

# Rename in order
for ($i = 0; $i -lt [Math]::Min($imageFiles.Count, $config.frames.Count); $i++) {
    $file = $imageFiles[$i]
    $newName = $config.frames[$i].name + $file.Extension
    $newPath = Join-Path $file.DirectoryName $newName
    
    Write-Host "Renaming: $($file.Name) -> $newName"
    Rename-Item -Path $file.FullName -NewName $newName
}

Write-Host "Renaming complete"
