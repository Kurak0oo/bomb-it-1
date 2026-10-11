param(
    [string]$Godot = 'godot',
    [switch]$Visual
)
$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot '../godot'
foreach ($check in @('sim_check', 'actors_check', 'view_check', 'timeline_check', 'campaign_check', 'special_check', 'soak_check')) {
    & $Godot --headless --path $projectPath --script "res://tests/$check.gd"
    if ($LASTEXITCODE -ne 0) { throw "$check failed with exit code $LASTEXITCODE" }
}
if ($Visual) {
    & $Godot --path $projectPath --script res://tests/ui_check.gd
    if ($LASTEXITCODE -ne 0) { throw "UI check failed with exit code $LASTEXITCODE" }
    & $Godot --path $projectPath --script res://tests/visual_timelines.gd
    if ($LASTEXITCODE -ne 0) { throw "Visual timelines failed with exit code $LASTEXITCODE" }
}
