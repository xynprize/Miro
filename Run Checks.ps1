$ErrorActionPreference = 'Stop'
$engine = 'C:\towerdefense\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$checks = @(
    @('res://tools/test_intro.gd'),
    @('res://tools/test_intro.gd', '--', '--c4'),
    @('res://tools/test_stealth_route.gd'),
    @('res://tools/test_intro_controls.gd'),
    @('res://tools/test_scaffold.gd'),
    @('res://tools/test_remaining_levels.gd'),
    @('res://tools/test_security.gd'),
    @('res://tools/test_brother.gd'),
    @('res://tools/test_ending.gd'),
    @('res://tools/test_gates_and_loot.gd'),
    @('res://tools/test_timed_stealth.gd'),
    @('res://tools/test_dialogue_layout.gd'),
    @('res://tools/test_audio.gd'),
    @('res://tools/test_music_and_world.gd'),
    @('res://tools/test_final_controls.gd'),
    @('res://tools/test_remote.gd'),
    @('res://tools/test_traversal_access.gd'),
    @('res://tools/test_weapon_inventory.gd'),
    @('res://tools/test_mouse_projectiles.gd'),
    @('res://tools/test_narrative_bubbles.gd')
)
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'tmp') | Out-Null
$index = 0
foreach ($check in $checks) {
    $index += 1
    $arguments = @('--headless', '--path', $PSScriptRoot, '--fixed-fps', '60', '--script') + $check
    $result = & $engine @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $result | Set-Content (Join-Path $PSScriptRoot "tmp/check-$index.log")
    if ($exitCode -ne 0 -or ($result -match 'SCRIPT ERROR:|ERROR:|FAIL:')) {
        $result | Write-Output
        throw "Level check $index failed."
    }
    $result | Select-String 'RESULT|failures='
}
Write-Output 'All level checks passed; no engine/script errors.'
