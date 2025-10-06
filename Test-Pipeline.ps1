# Test-Pipeline.ps1
# Complete end-to-end pipeline test

param(
    [Parameter(Mandatory=$false)]
    [string]$TestSize = "16x16",
    
    [Parameter(Mandatory=$false)]
    [int]$IconCount = 8,
    
    [Parameter(Mandatory=$false)]
    [switch]$Cleanup,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllSizes,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive
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

function Test-PipelineStep {
    param(
        [string]$StepName,
        [scriptblock]$TestScript
    )
    
    Write-Status "Testing: $StepName" "Info"
    try {
        $result = & $TestScript
        if ($result) {
            Write-Status "✓ $StepName - PASSED" "Success"
            return $true
        } else {
            Write-Status "✗ $StepName - FAILED" "Error"
            return $false
        }
    } catch {
        Write-Status "✗ $StepName - ERROR: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Cleanup function
function Remove-TestFiles {
    param([string]$Size = $TestSize)
    
    Write-Status "Cleaning up test files for $Size..." "Info"
    
    $testIconPath = "icons/$Size"
    $testAtlasPath = "atlas/$Size"
    
    # Remove generated test icons (look for the specific pattern we generate)
    if (Test-Path $testIconPath) {
        $testIcons = Get-ChildItem -Path $testIconPath -Filter "icon-home-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-user-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-gear-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-star-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-heart-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-mail-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-phone-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-camera-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-music-*" -ErrorAction SilentlyContinue
        $testIcons += Get-ChildItem -Path $testIconPath -Filter "icon-video-*" -ErrorAction SilentlyContinue
        
        if ($testIcons) {
            $testIcons | Remove-Item -Force
            Write-Status "Removed $($testIcons.Count) generated test icons from $testIconPath" "Info"
        }
    }
    
    # Remove test atlas files
    if (Test-Path $testAtlasPath) {
        $testAtlasFiles = Get-ChildItem -Path $testAtlasPath -Filter "*test*" -ErrorAction SilentlyContinue
        if ($testAtlasFiles) {
            $testAtlasFiles | Remove-Item -Force
            Write-Status "Removed $($testAtlasFiles.Count) test atlas files from $testAtlasPath" "Info"
        }
    }
}

# Test all sizes function
function Test-AllSizes {
    $sizes = @("16x16", "32x32", "48x48", "64x64")
    $totalResults = @()
    
    Write-Status "Testing all icon sizes: $($sizes -join ', ')" "Info"
    Write-Status "=========================================" "Info"
    
    foreach ($size in $sizes) {
        Write-Status "Testing size: $size" "Info"
        Write-Status "----------------------------------------" "Info"
        
        # Generate test icons for this size
        Write-Status "Generating test icons for $size..." "Info"
        $iconResult = & ".\Generate-Test-Icons.ps1" -IconSize $size -Count $IconCount
        
        # Generate atlas for this size
        Write-Status "Generating atlas for $size..." "Info"
        $atlasResult = & ".\Generate-Atlas.ps1" -IconSize $size -Padding 2
        
        # Quick validation
        $jsonPath = "atlas/$size/icon_set_$size`_atlas.json"
        $pngPath = "atlas/$size/icon_set_$size`_atlas.png"
        
        $jsonExists = Test-Path $jsonPath
        $pngExists = Test-Path $pngPath
        
        if ($jsonExists -and $pngExists) {
            Write-Status "✓ $size - Atlas generated successfully" "Success"
            $totalResults += @{ Size = $size; Success = $true }
        } else {
            Write-Status "✗ $size - Atlas generation failed" "Error"
            $totalResults += @{ Size = $size; Success = $false }
        }
        
        Write-Status "" "Info"
    }
    
    # Summary
    $successCount = ($totalResults | Where-Object { $_.Success -eq $true }).Count
    $totalCount = $totalResults.Count
    
    Write-Status "=========================================" "Info"
    Write-Status "ALL SIZES TEST RESULTS" "Info"
    Write-Status "=========================================" "Info"
    Write-Status "Total sizes tested: $totalCount" "Info"
    Write-Status "Successful: $successCount" "Success"
    Write-Status "Failed: $($totalCount - $successCount)" $(if (($totalCount - $successCount) -gt 0) { "Error" } else { "Info" })
    
    foreach ($result in $totalResults) {
        $status = if ($result.Success) { "✓ PASS" } else { "✗ FAIL" }
        $color = if ($result.Success) { "Success" } else { "Error" }
        Write-Status "$($result.Size): $status" $color
    }
    
    Write-Status "=========================================" "Info"
    
    if ($successCount -eq $totalCount) {
        Write-Status "🎉 ALL SIZES PASSED! Complete test data generated." "Success"
        Write-Status "" "Info"
        Write-Status "Next steps:" "Info"
        Write-Status "1. Open visual-asset-library.html in your browser" "Info"
        Write-Status "2. Test each size from the dropdown (16x16, 32x32, 48x48, 64x64)" "Info"
        Write-Status "3. Verify all icons display correctly" "Info"
    } else {
        Write-Status "❌ Some sizes failed. Check the output above for details." "Error"
    }
    
    return $totalResults
}

# Interactive mode function
function Show-InteractiveMenu {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Visual Asset Library - Test Pipeline" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose test option:" -ForegroundColor White
    Write-Host "1. Test single size (16x16)" -ForegroundColor White
    Write-Host "2. Test all sizes (16x16, 32x32, 48x48, 64x64)" -ForegroundColor White
    Write-Host "3. Cleanup all test data" -ForegroundColor White
    Write-Host "4. Exit" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter choice (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Testing single size (16x16)..." -ForegroundColor Green
            Write-Host ""
            return @{ Mode = "Single"; Size = "16x16"; Count = 8 }
        }
        "2" {
            Write-Host ""
            Write-Host "Testing all sizes..." -ForegroundColor Green
            Write-Host "This will generate test data for ALL icon sizes:" -ForegroundColor White
            Write-Host "• 16x16 icons (8 icons)" -ForegroundColor White
            Write-Host "• 32x32 icons (8 icons)" -ForegroundColor White
            Write-Host "• 48x48 icons (8 icons)" -ForegroundColor White
            Write-Host "• 64x64 icons (8 icons)" -ForegroundColor White
            Write-Host ""
            $confirm = Read-Host "Continue? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Host "Test cancelled." -ForegroundColor Yellow
                return $null
            }
            Write-Host ""
            return @{ Mode = "AllSizes"; Count = 8 }
        }
        "3" {
            Write-Host ""
            Write-Host "Cleaning up all test data..." -ForegroundColor Yellow
            return @{ Mode = "Cleanup" }
        }
        "4" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            return @{ Mode = "Exit" }
        }
        default {
            Write-Host "Invalid choice. Please enter 1-4." -ForegroundColor Red
            return Show-InteractiveMenu
        }
    }
}

# Main execution
Write-Status "Starting end-to-end pipeline test..." "Info"

# Handle interactive mode
if ($Interactive) {
    $menuResult = Show-InteractiveMenu
    if ($menuResult.Mode -eq "Exit") {
        exit 0
    }
    if ($menuResult.Mode -eq "Cleanup") {
        $AllSizes = $true
        $Cleanup = $true
    }
    if ($menuResult.Mode -eq "AllSizes") {
        $AllSizes = $true
        $IconCount = $menuResult.Count
    }
    if ($menuResult.Mode -eq "Single") {
        $TestSize = $menuResult.Size
        $IconCount = $menuResult.Count
    }
}

if ($AllSizes) {
    Write-Status "Running comprehensive test for ALL icon sizes" "Info"
    Write-Status "Icon count per size: $IconCount" "Info"
    Test-AllSizes
    exit 0
}

if ($Cleanup) {
    if ($AllSizes) {
        $sizes = @("16x16", "32x32", "48x48", "64x64")
        foreach ($size in $sizes) {
            Remove-TestFiles -Size $size
        }
    } else {
        Remove-TestFiles
    }
    Write-Status "Cleanup complete" "Success"
    exit 0
}

Write-Status "Test size: $TestSize, Icon count: $IconCount" "Info"

$testResults = @()

# Step 1: Generate test icons
$testResults += Test-PipelineStep "Generate Test Icons" {
    Write-Status "Running Generate-Test-Icons.ps1..." "Info"
    $iconResult = & ".\Generate-Test-Icons.ps1" -IconSize $TestSize -Count $IconCount
    $testIcons = Get-ChildItem -Path "icons/$TestSize" -Filter "icon-home-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-user-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-gear-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-star-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-heart-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-mail-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-phone-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-camera-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-music-*" -ErrorAction SilentlyContinue
    $testIcons += Get-ChildItem -Path "icons/$TestSize" -Filter "icon-video-*" -ErrorAction SilentlyContinue
    
    if (-not $testIcons) {
        Write-Status "No test icons found in icons/$TestSize" "Error"
        return $false
    }
    
    if ($testIcons.Count -ne $IconCount) {
        Write-Status "Expected $IconCount icons, found $($testIcons.Count)" "Warning"
        return $false
    }
    
    Write-Status "Found $($testIcons.Count) test icons" "Success"
    return $true
}

# Step 2: Generate atlas
$testResults += Test-PipelineStep "Generate Atlas" {
    Write-Status "Running Generate-Atlas.ps1..." "Info"
    $atlasResult = & ".\Generate-Atlas.ps1" -IconSize $TestSize -Padding 2
    
    $atlasPath = "atlas/$TestSize"
    $jsonPath = "$atlasPath/icon_set_$TestSize`_atlas.json"
    $pngPath = "$atlasPath/icon_set_$TestSize`_atlas.png"
    
    $jsonExists = Test-Path $jsonPath
    $pngExists = Test-Path $pngPath
    
    if (-not $jsonExists) {
        Write-Status "JSON file not found: $jsonPath" "Error"
        return $false
    }
    
    if (-not $pngExists) {
        Write-Status "PNG file not found: $pngPath" "Error"
        return $false
    }
    
    Write-Status "Atlas files created successfully" "Success"
    return $true
}

# Step 3: Validate atlas structure
$testResults += Test-PipelineStep "Validate Atlas Structure" {
    $jsonPath = "atlas/$TestSize/icon_set_$TestSize`_atlas.json"
    
    if (-not (Test-Path $jsonPath)) {
        Write-Status "JSON file not found: $jsonPath" "Error"
        return $false
    }
    
    try {
        $atlasData = Get-Content $jsonPath | ConvertFrom-Json
    } catch {
        Write-Status "Failed to parse JSON: $($_.Exception.Message)" "Error"
        return $false
    }
    
    # Check required structure
    $hasMeta = $atlasData.meta -ne $null
    $hasFrames = $atlasData.frames -ne $null -and $atlasData.frames.Count -gt 0
    $hasImageRef = $atlasData.meta.image -ne $null
    
    if (-not $hasMeta) {
        Write-Status "Missing 'meta' section in JSON" "Error"
        return $false
    }
    
    if (-not $hasFrames) {
        Write-Status "Missing or empty 'frames' array in JSON" "Error"
        return $false
    }
    
    if (-not $hasImageRef) {
        Write-Status "Missing 'image' reference in meta section" "Error"
        return $false
    }
    
    Write-Status "JSON structure validation passed" "Success"
    return $true
}

# Step 4: Test rename functionality
$testResults += Test-PipelineStep "Test Rename Icons" {
    $jsonPath = "atlas/$TestSize/icon_set_$TestSize`_atlas.json"
    $iconPath = "icons/$TestSize"
    
    if (-not (Test-Path $jsonPath)) {
        Write-Status "JSON file not found for rename test: $jsonPath" "Error"
        return $false
    }
    
    if (-not (Test-Path $iconPath)) {
        Write-Status "Icon directory not found: $iconPath" "Error"
        return $false
    }
    
    Write-Status "Running Rename-Icons.ps1..." "Info"
    $renameResult = & ".\Rename-Icons.ps1" -ImageDirectory $iconPath -JsonPath $jsonPath
    
    # Check if files still exist and are properly named
    $iconFiles = Get-ChildItem -Path $iconPath -Filter "*.png" -ErrorAction SilentlyContinue
    
    if (-not $iconFiles) {
        Write-Status "No PNG files found in $iconPath after rename" "Error"
        return $false
    }
    
    Write-Status "Found $($iconFiles.Count) PNG files after rename" "Success"
    return $true
}

# Step 5: Validate web assets
$testResults += Test-PipelineStep "Validate Web Assets" {
    $atlasPath = "atlas/$TestSize"
    $jsonPath = "$atlasPath/icon_set_$TestSize`_atlas.json"
    $pngPath = "$atlasPath/icon_set_$TestSize`_atlas.png"
    
    # Check files exist
    $jsonExists = Test-Path $jsonPath
    $pngExists = Test-Path $pngPath
    
    if (-not ($jsonExists -and $pngExists)) {
        return $false
    }
    
    # Check JSON is valid
    try {
        $atlasData = Get-Content $jsonPath | ConvertFrom-Json
        $validJson = $atlasData.meta -ne $null -and $atlasData.frames -ne $null
    } catch {
        return $false
    }
    
    return $validJson
}

# Step 6: Test web display (basic validation)
$testResults += Test-PipelineStep "Test Web Display Assets" {
    $atlasPath = "atlas/$TestSize"
    $jsonPath = "$atlasPath/icon_set_$TestSize`_atlas.json"
    
    if (-not (Test-Path $jsonPath)) {
        return $false
    }
    
    $atlasData = Get-Content $jsonPath | ConvertFrom-Json
    
    # Check if visual-asset-library.html can load this data
    $hasRequiredFields = $atlasData.meta.image -ne $null -and 
                       $atlasData.meta.size -ne $null -and 
                       $atlasData.frames -ne $null
    
    return $hasRequiredFields
}

# Report results
$passedCount = ($testResults | Where-Object { $_ -eq $true }).Count
$totalCount = $testResults.Count
$failedCount = $totalCount - $passedCount

Write-Status "=========================================" "Info"
Write-Status "PIPELINE TEST RESULTS" "Info"
Write-Status "=========================================" "Info"
Write-Status "Total tests: $totalCount" "Info"
Write-Status "Passed: $passedCount" "Success"
Write-Status "Failed: $failedCount" $(if ($failedCount -gt 0) { "Error" } else { "Info" })
Write-Status "=========================================" "Info"

if ($passedCount -eq $totalCount) {
    Write-Status "🎉 ALL TESTS PASSED! Pipeline is working correctly." "Success"
    Write-Status "" "Info"
    Write-Status "Next steps:" "Info"
    Write-Status "1. Open visual-asset-library.html in your browser" "Info"
    Write-Status "2. Select '$TestSize' from the size dropdown" "Info"
    Write-Status "3. Verify test icons are displayed correctly" "Info"
    Write-Status "" "Info"
    Write-Status "To cleanup test files, run:" "Info"
    Write-Status "  .\Test-Pipeline.ps1 -Cleanup" "Info"
} else {
    Write-Status "❌ $failedCount test(s) failed. Check the output above for details." "Error"
    Write-Status "" "Info"
    Write-Status "Common issues:" "Info"
    Write-Status "- Missing PowerShell execution policy (run as Administrator)" "Info"
    Write-Status "- Missing System.Drawing assembly" "Info"
    Write-Status "- File permission issues" "Info"
    Write-Status "- Invalid file paths" "Info"
}

Write-Status "Test complete." "Info"

# Show usage help if no parameters provided
if (-not $Interactive -and -not $AllSizes -and -not $Cleanup -and $TestSize -eq "16x16" -and $IconCount -eq 8) {
    Write-Status "" "Info"
    Write-Status "Usage examples:" "Info"
    Write-Status "  .\Test-Pipeline.ps1 -Interactive          # Interactive menu" "Info"
    Write-Status "  .\Test-Pipeline.ps1 -AllSizes            # Test all sizes" "Info"
    Write-Status "  .\Test-Pipeline.ps1 -TestSize 32x32      # Test specific size" "Info"
    Write-Status "  .\Test-Pipeline.ps1 -AllSizes -Cleanup   # Cleanup all test data" "Info"
    Write-Status "" "Info"
}
