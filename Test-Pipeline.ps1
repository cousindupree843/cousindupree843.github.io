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
    
    # Remove test icons
    if (Test-Path $testIconPath) {
        $testIcons = Get-ChildItem -Path $testIconPath -Filter "icon-test-*" -ErrorAction SilentlyContinue
        if ($testIcons) {
            $testIcons | Remove-Item -Force
            Write-Status "Removed $($testIcons.Count) test icons from $testIconPath" "Info"
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

# Main execution
Write-Status "Starting end-to-end pipeline test..." "Info"

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
    $testIcons = Get-ChildItem -Path "icons/$TestSize" -Filter "icon-test-*" -ErrorAction SilentlyContinue
    
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
