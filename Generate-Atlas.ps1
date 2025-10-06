# Generate-Atlas.ps1
# Automated atlas generation script for the Visual Asset Library

param(
    [Parameter(Mandatory=$false)]
    [string]$IconSize = "16x16",
    
    [Parameter(Mandatory=$false)]
    [int]$Padding = 2,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllSizes
)

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Type) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-IconDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Status "Icon directory not found: $Path" "Error"
        return $false
    }
    
    $iconFiles = Get-ChildItem -Path $Path -Filter "*.png" | Where-Object { $_.Name -match "icon-.*-\d+\.png" }
    
    if ($iconFiles.Count -eq 0) {
        Write-Status "No valid icon files found in $Path" "Warning"
        return $false
    }
    
    Write-Status "Found $($iconFiles.Count) icon files in $Path" "Success"
    return $true
}

function Get-IconFiles {
    param([string]$Path)
    
    $iconFiles = Get-ChildItem -Path $Path -Filter "*.png" | Where-Object { $_.Name -match "icon-.*-\d+\.png" }
    return $iconFiles | Sort-Object Name
}

function New-AtlasJson {
    param(
        [string]$IconSize,
        [array]$IconFiles,
        [int]$Padding,
        [int]$CanvasWidth,
        [int]$CanvasHeight,
        [int]$CellWidth,
        [int]$CellHeight,
        [int]$Columns,
        [int]$Rows
    )
    
    $frames = @()
    $order = @()
    
    for ($i = 0; $i -lt $IconFiles.Count; $i++) {
        $file = $IconFiles[$i]
        $row = [Math]::Floor($i / $Columns)
        $col = $i % $Columns
        
        $x = $Padding + $col * ($CellWidth + $Padding)
        $y = $Padding + $row * ($CellHeight + $Padding)
        
        $spriteName = $file.BaseName
        
        $frame = @{
            name = $spriteName
            index = $i
            row = $row
            col = $col
            x = $x
            y = $y
            w = $CellWidth
            h = $CellHeight
        }
        
        $frames += $frame
        $order += $file.Name
    }
    
    $atlasData = @{
        meta = @{
            image = "icon_set_$IconSize`_atlas.png"
            size = @{
                w = $CanvasWidth
                h = $CanvasHeight
            }
            cell = @{
                w = $CellWidth
                h = $CellHeight
            }
            padding = $Padding
            columns = $Columns
            rows = $Rows
            count = $IconFiles.Count
            order = $order
        }
        frames = $frames
    }
    
    return $atlasData
}

function New-AtlasCsv {
    param(
        [array]$IconFiles,
        [int]$Padding,
        [int]$CellWidth,
        [int]$CellHeight,
        [int]$Columns
    )
    
    $csvLines = @("index,name,row,col,x,y,w,h")
    
    for ($i = 0; $i -lt $IconFiles.Count; $i++) {
        $file = $IconFiles[$i]
        $row = [Math]::Floor($i / $Columns)
        $col = $i % $Columns
        
        $x = $Padding + $col * ($CellWidth + $Padding)
        $y = $Padding + $row * ($CellHeight + $Padding)
        
        $csvLine = "$i,$($file.BaseName),$row,$col,$x,$y,$CellWidth,$CellHeight"
        $csvLines += $csvLine
    }
    
    return $csvLines -join "`n"
}

function New-AtlasXml {
    param(
        [string]$IconSize,
        [array]$IconFiles,
        [int]$Padding,
        [int]$CanvasWidth,
        [int]$CanvasHeight,
        [int]$CellWidth,
        [int]$CellHeight,
        [int]$Columns,
        [int]$Rows
    )
    
    $orderXml = ""
    foreach ($file in $IconFiles) {
        $orderXml += "<file>$($file.Name)</file>"
    }
    
    $xml = @"
<atlas>
    <meta>
        <image>icon_set_$IconSize`_atlas.png</image>
        <size><w>$CanvasWidth</w><h>$CanvasHeight</h></size>
        <cell><w>$CellWidth</w><h>$CellHeight</h></cell>
        <padding>$Padding</padding>
        <columns>$Columns</columns>
        <rows>$Rows</rows>
        <count>$($IconFiles.Count)</count>
        <order>$orderXml</order>
    </meta>
</atlas>
"@
    
    return $xml
}

function New-AtlasPng {
    param(
        [string]$IconSize,
        [array]$IconFiles,
        [int]$Padding,
        [int]$CanvasWidth,
        [int]$CanvasHeight,
        [int]$CellWidth,
        [int]$CellHeight,
        [int]$Columns,
        [int]$Rows,
        [string]$OutputPath
    )
    
    try {
        # Load System.Drawing assembly
        Add-Type -AssemblyName System.Drawing
        
        # Create bitmap with transparent background
        $bitmap = New-Object System.Drawing.Bitmap($CanvasWidth, $CanvasHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Set high quality rendering
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        
        # Clear with transparent background
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        # Draw each icon
        for ($i = 0; $i -lt $IconFiles.Count; $i++) {
            $file = $IconFiles[$i]
            $row = [Math]::Floor($i / $Columns)
            $col = $i % $Columns
            
            $x = $Padding + $col * ($CellWidth + $Padding)
            $y = $Padding + $row * ($CellHeight + $Padding)
            
            try {
                # Load and draw image
                $iconImage = [System.Drawing.Image]::FromFile($file.FullName)
                $graphics.DrawImage($iconImage, $x, $y, $CellWidth, $CellHeight)
                $iconImage.Dispose()
            } catch {
                Write-Status "Failed to process image: $($file.Name) - $($_.Exception.Message)" "Warning"
            }
        }
        
        # Save PNG with high quality
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        # Cleanup
        $graphics.Dispose()
        $bitmap.Dispose()
        
        return $true
    } catch {
        Write-Status "PNG generation failed: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Invoke-IconSizeProcessing {
    param([string]$IconSize)
    
    Write-Status "Processing $IconSize icons..." "Info"
    
    $iconPath = "icons/$IconSize"
    $atlasPath = "atlas/$IconSize"
    
    # Check if icon directory exists
    if (-not (Test-IconDirectory $iconPath)) {
        return $false
    }
    
    # Get icon files
    $iconFiles = Get-IconFiles $iconPath
    if ($iconFiles.Count -eq 0) {
        Write-Status "No icon files found for $IconSize" "Warning"
        return $false
    }
    
    # Create atlas directory if it doesn't exist
    if (-not (Test-Path $atlasPath)) {
        New-Item -ItemType Directory -Path $atlasPath -Force | Out-Null
        Write-Status "Created atlas directory: $atlasPath" "Success"
    }
    
    # Calculate grid dimensions
    $columns = [Math]::Ceiling([Math]::Sqrt($iconFiles.Count))
    $rows = [Math]::Ceiling($iconFiles.Count / $columns)
    
    # Calculate cell size (assuming all icons are the same size)
    $cellWidth = 16  # Standard icon size
    $cellHeight = 16
    
    # Calculate canvas dimensions
    $canvasWidth = $Padding + $columns * ($cellWidth + $Padding)
    $canvasHeight = $Padding + $rows * ($cellHeight + $Padding)
    
    Write-Status "Grid: $columns columns × $rows rows" "Info"
    Write-Status "Canvas: $canvasWidth × $canvasHeight pixels" "Info"
    
    # Generate JSON
    $atlasData = New-AtlasJson -IconSize $IconSize -IconFiles $iconFiles -Padding $Padding -CanvasWidth $canvasWidth -CanvasHeight $canvasHeight -CellWidth $cellWidth -CellHeight $cellHeight -Columns $columns -Rows $rows
    
    $jsonPath = "$atlasPath/icon_set_$IconSize`_atlas.json"
    $atlasData | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Status "Generated JSON: $jsonPath" "Success"
    
    # Generate CSV
    $csvContent = New-AtlasCsv -IconFiles $iconFiles -Padding $Padding -CellWidth $cellWidth -CellHeight $cellHeight -Columns $columns
    $csvPath = "$atlasPath/icon_set_$IconSize`_atlas.csv"
    $csvContent | Set-Content -Path $csvPath -Encoding UTF8
    Write-Status "Generated CSV: $csvPath" "Success"
    
    # Generate XML
    $xmlContent = New-AtlasXml -IconSize $IconSize -IconFiles $iconFiles -Padding $Padding -CanvasWidth $canvasWidth -CanvasHeight $canvasHeight -CellWidth $cellWidth -CellHeight $cellHeight -Columns $columns -Rows $rows
    $xmlPath = "$atlasPath/icon_set_$IconSize`_atlas.xml"
    $xmlContent | Set-Content -Path $xmlPath -Encoding UTF8
    Write-Status "Generated XML: $xmlPath" "Success"
    
    # Generate PNG spritesheet
    $pngPath = "$atlasPath/icon_set_$IconSize`_atlas.png"
    if (New-AtlasPng -IconSize $IconSize -IconFiles $iconFiles -Padding $Padding -CanvasWidth $canvasWidth -CanvasHeight $canvasHeight -CellWidth $cellWidth -CellHeight $cellHeight -Columns $columns -Rows $rows -OutputPath $pngPath) {
        Write-Status "Generated PNG: $pngPath" "Success"
    } else {
        Write-Status "Failed to generate PNG: $pngPath" "Error"
        return $false
    }
    
    return $true
}

# Main execution
Write-Status "Starting atlas generation process..." "Info"

if ($AllSizes) {
    $sizes = @("16x16", "32x32", "48x48", "64x64")
    $successCount = 0
    
    foreach ($size in $sizes) {
        if (Invoke-IconSizeProcessing -IconSize $size) {
            $successCount++
        }
    }
    
    Write-Status "Completed processing $successCount of $($sizes.Count) sizes" "Info"
} else {
    if (Invoke-IconSizeProcessing -IconSize $IconSize) {
        Write-Status "Atlas generation completed for $IconSize" "Success"
    } else {
        Write-Status "Atlas generation failed for $IconSize" "Error"
        exit 1
    }
}

Write-Status "Atlas generation process completed" "Success"
