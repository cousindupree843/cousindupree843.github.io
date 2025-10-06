# Generate-Test-Icons.ps1
# Generate test PNG icons for pipeline testing

param(
    [Parameter(Mandatory=$false)]
    [string]$IconSize = "16x16",
    
    [Parameter(Mandatory=$false)]
    [int]$Count = 10,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "icons/$IconSize"
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

function New-TestIcon {
    param(
        [string]$Name,
        [int]$Size,
        [string]$OutputPath,
        [string]$Color,
        [string]$Text
    )
    
    try {
        # Load System.Drawing assembly
        Add-Type -AssemblyName System.Drawing
        
        # Create bitmap
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Set high quality rendering
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        
        # Clear with transparent background
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        # Draw background circle
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromName($Color))
        $graphics.FillEllipse($brush, 1, 1, $Size - 2, $Size - 2)
        
        # Draw border
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1)
        $graphics.DrawEllipse($pen, 1, 1, $Size - 2, $Size - 2)
        
        # Draw text if size allows
        if ($Size -ge 16) {
            $font = New-Object System.Drawing.Font("Arial", [Math]::Max(6, $Size / 3), [System.Drawing.FontStyle]::Bold)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            
            # Center the text
            $textSize = $graphics.MeasureString($Text, $font)
            $x = ($Size - $textSize.Width) / 2
            $y = ($Size - $textSize.Height) / 2
            
            $graphics.DrawString($Text, $font, $textBrush, $x, $y)
            
            $font.Dispose()
            $textBrush.Dispose()
        }
        
        # Save PNG
        $fullPath = Join-Path $OutputPath "$Name.png"
        $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        # Cleanup
        $brush.Dispose()
        $pen.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
        
        return $fullPath
    } catch {
        Write-Status "Failed to create icon $Name : $($_.Exception.Message)" "Error"
        return $null
    }
}

# Main execution
Write-Status "Starting test icon generation..." "Info"
Write-Status "Target: $Count icons for size $IconSize" "Info"
Write-Status "Output directory: $OutputPath" "Info"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    try {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Status "Created output directory: $OutputPath" "Success"
    } catch {
        Write-Status "Failed to create directory: $($_.Exception.Message)" "Error"
        exit 1
    }
} else {
    Write-Status "Output directory exists: $OutputPath" "Info"
}

# Parse size with validation
try {
    $size = [int]($IconSize -replace 'x\d+', '')
    if ($size -lt 8 -or $size -gt 256) {
        Write-Status "Warning: Icon size $size may not be optimal (recommended: 16-64)" "Warning"
    }
} catch {
    Write-Status "Invalid icon size format: $IconSize (expected: 16x16)" "Error"
    exit 1
}

$colors = @("Red", "Blue", "Green", "Orange", "Purple", "Cyan", "Magenta", "Yellow", "Lime", "Pink")
$icons = @("home", "user", "gear", "star", "heart", "mail", "phone", "camera", "music", "video")

$createdCount = 0
$failedCount = 0

Write-Status "Generating $Count test icons..." "Info"

for ($i = 0; $i -lt $Count; $i++) {
    $iconName = "icon-$($icons[$i % $icons.Count])-$size"
    $color = $colors[$i % $colors.Count]
    $text = $icons[$i % $icons.Count].Substring(0, 1).ToUpper()
    
    $result = New-TestIcon -Name $iconName -Size $size -OutputPath $OutputPath -Color $color -Text $text
    
    if ($result) {
        Write-Status "✓ Created: $iconName.png" "Success"
        $createdCount++
    } else {
        Write-Status "✗ Failed: $iconName.png" "Error"
        $failedCount++
    }
}

# Final summary
Write-Status "Generation complete: $createdCount successful, $failedCount failed" "Info"
if ($createdCount -gt 0) {
    Write-Status "Icons saved to: $OutputPath" "Success"
}
if ($failedCount -gt 0) {
    Write-Status "Some icons failed to generate. Check error messages above." "Warning"
}
