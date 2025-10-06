# Validate-Atlas.ps1
# Validation script to prevent atlas/source mismatches

param(
    [Parameter(Mandatory=$false)]
    [string]$IconSize = "16x16",
    
    [Parameter(Mandatory=$false)]
    [switch]$AllSizes,
    
    [Parameter(Mandatory=$false)]
    [switch]$Fix
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

function Test-AtlasConsistency {
    param([string]$IconSize)
    
    Write-Status "Validating atlas consistency for $IconSize..." "Info"
    
    $iconPath = "icons/$IconSize"
    $atlasPath = "atlas/$IconSize"
    $jsonPath = "$atlasPath/icon_set_$IconSize`_atlas.json"
    $pngPath = "$atlasPath/icon_set_$IconSize`_atlas.png"
    
    $issues = @()
    $warnings = @()
    
    # Check if directories exist
    if (-not (Test-Path $iconPath)) {
        $issues += "Icon directory not found: $iconPath"
    }
    
    if (-not (Test-Path $atlasPath)) {
        $issues += "Atlas directory not found: $atlasPath"
    }
    
    # Check if JSON exists
    if (-not (Test-Path $jsonPath)) {
        $issues += "Atlas JSON not found: $jsonPath"
    } else {
        try {
            $atlasData = Get-Content $jsonPath | ConvertFrom-Json
            
            # Check if PNG exists
            if (-not (Test-Path $pngPath)) {
                $warnings += "Atlas PNG not found: $pngPath"
            }
            
            # Validate JSON structure
            if (-not $atlasData.meta) {
                $issues += "Invalid JSON structure: missing 'meta' section"
            } else {
                # Check image filename consistency
                $expectedImageName = "icon_set_$IconSize`_atlas.png"
                if ($atlasData.meta.image -ne $expectedImageName) {
                    $issues += "Image filename mismatch: expected '$expectedImageName', found '$($atlasData.meta.image)'"
                }
                
                # Check if PNG file matches JSON reference
                if ((Test-Path $pngPath) -and $atlasData.meta.image -ne (Split-Path $pngPath -Leaf)) {
                    $issues += "PNG filename doesn't match JSON reference"
                }
            }
            
            # Check frames vs source files
            if ($atlasData.frames) {
                $sourceFiles = Get-ChildItem -Path $iconPath -Filter "*.png" -ErrorAction SilentlyContinue
                $sourceFileNames = $sourceFiles | ForEach-Object { $_.Name }
                
                # Check for missing source files
                foreach ($frame in $atlasData.frames) {
                    $expectedFileName = "$($frame.name).png"
                    if ($expectedFileName -notin $sourceFileNames) {
                        $warnings += "Source file not found: $expectedFileName"
                    }
                }
                
                # Check for extra source files not in atlas
                foreach ($sourceFile in $sourceFiles) {
                    $frameName = $sourceFile.BaseName
                    $frameExists = $atlasData.frames | Where-Object { $_.name -eq $frameName }
                    if (-not $frameExists) {
                        $warnings += "Source file not in atlas: $($sourceFile.Name)"
                    }
                }
                
                # Check count consistency
                if ($atlasData.meta.count -ne $atlasData.frames.Count) {
                    $issues += "Frame count mismatch: meta.count=$($atlasData.meta.count), frames.Count=$($atlasData.frames.Count)"
                }
                
                if ($atlasData.meta.count -ne $sourceFiles.Count) {
                    $warnings += "Source file count mismatch: atlas has $($atlasData.meta.count) frames, but $($sourceFiles.Count) source files found"
                }
            }
            
        } catch {
            $issues += "Failed to parse JSON: $($_.Exception.Message)"
        }
    }
    
    # Report results
    if ($issues.Count -gt 0) {
        Write-Status "CRITICAL ISSUES found for ${IconSize}:" "Error"
        foreach ($issue in $issues) {
            Write-Status "  - $issue" "Error"
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Status "WARNINGS for ${IconSize}:" "Warning"
        foreach ($warning in $warnings) {
            Write-Status "  - $warning" "Warning"
        }
    }
    
    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Status "Atlas validation passed for ${IconSize}" "Success"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        IsValid = ($issues.Count -eq 0)
    }
}

function Repair-Atlas {
    param([string]$IconSize)
    
    Write-Status "Attempting to repair atlas for $IconSize..." "Info"
    
    $iconPath = "icons/$IconSize"
    
    if (-not (Test-Path $iconPath)) {
        Write-Status "Cannot repair: source directory not found" "Error"
        return $false
    }
    
    # Run the atlas generation script
    $scriptPath = "Generate-Atlas.ps1"
    if (Test-Path $scriptPath) {
        Write-Status "Running atlas generation..." "Info"
        & $scriptPath -IconSize $IconSize
        return $?
    } else {
        Write-Status "Atlas generation script not found: $scriptPath" "Error"
        return $false
    }
}

# Main execution
Write-Status "Starting atlas validation..." "Info"

if ($AllSizes) {
    $sizes = @("16x16", "32x32", "48x48", "64x64")
    $totalIssues = 0
    $totalWarnings = 0
    
    foreach ($size in $sizes) {
        $result = Test-AtlasConsistency -IconSize $size
        $totalIssues += $result.Issues.Count
        $totalWarnings += $result.Warnings.Count
        
        if (-not $result.IsValid -and $Fix) {
            Write-Status "Attempting to fix $size..." "Info"
            Repair-Atlas -IconSize $size
        }
    }
    
    Write-Status "Validation complete: $totalIssues issues, $totalWarnings warnings across all sizes" "Info"
} else {
    $result = Test-AtlasConsistency -IconSize $IconSize
    
    if (-not $result.IsValid -and $Fix) {
        Write-Status "Attempting to fix $IconSize..." "Info"
        Repair-Atlas -IconSize $IconSize
    }
}

Write-Status "Atlas validation completed" "Success"
