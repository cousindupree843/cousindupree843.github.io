# Test-All-Sizes.ps1
# Quick script to test all icon sizes with comprehensive test data

param(
    [Parameter(Mandatory=$false)]
    [int]$IconCount = 12,
    
    [Parameter(Mandatory=$false)]
    [switch]$Cleanup
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Visual Asset Library - Complete Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($Cleanup) {
    Write-Host "Cleaning up all test data..." -ForegroundColor Yellow
    & ".\Test-Pipeline.ps1" -AllSizes -Cleanup
    Write-Host "Cleanup complete!" -ForegroundColor Green
    exit 0
}

Write-Host "This will generate test data for ALL icon sizes:" -ForegroundColor White
Write-Host "• 16x16 icons ($IconCount icons)" -ForegroundColor White
Write-Host "• 32x32 icons ($IconCount icons)" -ForegroundColor White
Write-Host "• 48x48 icons ($IconCount icons)" -ForegroundColor White
Write-Host "• 64x64 icons ($IconCount icons)" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Test cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting comprehensive test..." -ForegroundColor Green
Write-Host ""

# Run the comprehensive test
& ".\Test-Pipeline.ps1" -AllSizes -IconCount $IconCount

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To cleanup all test data, run:" -ForegroundColor White
Write-Host "  .\Test-All-Sizes.ps1 -Cleanup" -ForegroundColor Gray
Write-Host ""
