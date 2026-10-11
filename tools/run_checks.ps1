param(
    [string]$Godot = 'godot',
    [switch]$Visual,
    [int]$TimeoutSeconds = 120,
    [string]$Output = '',
    [string]$CompareBaselines = ''
)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'run_checks.py'), '--godot', $Godot, '--timeout', $TimeoutSeconds)
if ($Visual) { $arguments += '--visual' }
if ($Output) { $arguments += @('--output', $Output) }
if ($CompareBaselines) { $arguments += @('--compare-baselines', $CompareBaselines) }
& python @arguments
if ($LASTEXITCODE -ne 0) { throw "Project checks failed. See the reported phase log." }
