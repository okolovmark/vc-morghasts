$ErrorActionPreference = 'Stop'
$scratch = "C:\Users\okolo\AppData\Local\Temp\claude\C--Program-Files--x86--Steam-steamapps-common-Total-War-WARHAMMER-III\3bda4f82-c64b-4f39-8a87-f75b557a77f7\scratchpad"
$dec = "$scratch\decompressed"

function New-CaString([string]$s) {
    $b = [Text.Encoding]::UTF8.GetBytes($s)
    return ,([BitConverter]::GetBytes([uint16]$b.Length) + $b)
}
function New-TableHeader([int]$rowCount, [int]$version) {
    $guid = [Guid]::NewGuid().ToString()
    $h = [byte[]]@(0xfd,0xfe,0xfc,0xff) + [BitConverter]::GetBytes([uint16]$guid.Length) + [Text.Encoding]::Unicode.GetBytes($guid)
    if ($version -gt 0) { $h += [byte[]]@(0xfc,0xfd,0xfe,0xff) + [BitConverter]::GetBytes([int32]$version) }
    $h += [byte[]]@(1) + [BitConverter]::GetBytes([uint32]$rowCount)
    return ,$h
}

$HARB = 'wh3_dlc29_vmp_mon_morghast_harbingers'
$ARCH = 'wh3_dlc29_vmp_mon_morghast_archai'
$ARCH_ROR = 'wh3_dlc29_vmp_mon_morghast_archai_ror'
$EFF_HARB = 'vc_morghasts_unit_cap_harbingers'
$EFF_ARCH = 'vc_morghasts_unit_cap_archai'

# ========== 1. units_to_groupings_military_permissions (no version) ==========
$permRows = @(
    @($HARB,'wh_main_group_vampire_counts'),
    @($ARCH,'wh_main_group_vampire_counts')
)
$perm = New-TableHeader $permRows.Count 0
foreach ($r in $permRows) { $perm += New-CaString $r[0]; $perm += New-CaString $r[1] }

# ========== 2. building_units_allowed v4: [building][unit][i32 0][f32 key][i32 0][i16 0] ==========
$bldRows = @(
    @('wh_main_vmp_forest_4',$HARB),
    @('wh_main_vmp_forest_5',$HARB),
    @('wh_main_vmp_forest_5',$ARCH)
)
$rand = New-Object Random 777123
$bld = New-TableHeader $bldRows.Count 4
foreach ($r in $bldRows) {
    $bld += New-CaString $r[0]
    $bld += New-CaString $r[1]
    $bld += [BitConverter]::GetBytes([int32]0)
    $bld += [BitConverter]::GetBytes([single]$rand.NextDouble())
    $bld += [BitConverter]::GetBytes([int32]0)
    $bld += [BitConverter]::GetBytes([int16]0)
}

# ========== 3. character_skill_nodes v6: copy 2 rows, clear subculture ==========
$b = [IO.File]::ReadAllBytes("$dec\db__character_skill_nodes_tables__data__")
$p = 0
if ($b[0] -eq 0xfd) { $glen = [BitConverter]::ToUInt16($b,4); $p = 6 + $glen*2 }
if ($b[$p] -eq 0xfc) { $p += 8 }
$p += 1
$count = [BitConverter]::ToUInt32($b, $p); $p += 4
$targets = @('wh_main_skill_node_vmp_mannfred_unique_11','wh3_dlc29_skill_node_vmp_neferata_unique_07')
$found = @{}
function Read-S([byte[]]$b,[ref]$p) { $len=[BitConverter]::ToUInt16($b,$p.Value); $p.Value += 2+$len; return [Text.Encoding]::UTF8.GetString($b,$p.Value-$len,$len) }
function Skip-O([byte[]]$b,[ref]$p) { $f=$b[$p.Value]; $p.Value++; if ($f -eq 1) { $len=[BitConverter]::ToUInt16($b,$p.Value); $p.Value += 2+$len } }
for ($r = 0; $r -lt $count; $r++) {
    $rowStart = $p
    $rp = [ref]$p
    Skip-O $b $rp
    $skill = Read-S $b $rp
    Skip-O $b $rp
    $p += 4
    $key = Read-S $b $rp
    $p += 4
    $subFlagPos = $p
    Skip-O $b $rp
    $afterSub = $p
    $p += 9
    if ($targets -contains $key) {
        $pre = $b[$rowStart..($subFlagPos-1)]
        $tail = $b[$afterSub..($p-1)]
        $found[$key] = [byte[]]$pre + [byte[]]@(0) + [byte[]]$tail
    }
}
if ($p -ne $b.Length) { throw "character_skill_nodes reparse mismatch: $p/$($b.Length)" }
foreach ($t in $targets) { if (-not $found.ContainsKey($t)) { throw "node row not found: $t" } }
$nodes = New-TableHeader $targets.Count 6
foreach ($t in $targets) { $nodes += $found[$t] }
Write-Host "skill nodes cloned: $($targets.Count)"

# ========== 4. unit_set_to_unit_junctions v1: [b0][o0][o0][o0][o1 unit][s set] ==========
$setRows = @(
    @($HARB,    'wh2_dlc11_vmp_vets_fell_bats_vargheists_terrorgheists_zombie_dragon'),
    @($ARCH,    'wh2_dlc11_vmp_vets_fell_bats_vargheists_terrorgheists_zombie_dragon'),
    @($ARCH_ROR,'wh2_dlc11_vmp_vets_fell_bats_vargheists_terrorgheists_ror'),
    @($HARB,    'wh3_dlc29_vmp_black_knights_blood_knights_drakenhof_templars'),
    @($ARCH,    'wh3_dlc29_vmp_black_knights_blood_knights_drakenhof_templars')
)
$setj = New-TableHeader $setRows.Count 1
foreach ($r in $setRows) {
    $setj += [byte[]]@(0,0,0,0,1)
    $setj += New-CaString $r[0]
    $setj += New-CaString $r[1]
}

# ========== 5. effects (no version): clone TK cap rows with new keys ==========
$eb = [IO.File]::ReadAllBytes("$dec\db__effects_tables__data__")
$p = 0
if ($eb[0] -eq 0xfd) { $glen = [BitConverter]::ToUInt16($eb,4); $p = 6 + $glen*2 }
if ($eb[$p] -eq 0xfc) { $p += 8 }
$p += 1
$cnt = [BitConverter]::ToUInt32($eb, $p); $p += 4
$effSrc = @{ 'wh2_dlc09_effect_unit_cap_tmb_mon_morghast_harbingers' = $EFF_HARB; 'wh2_dlc09_effect_unit_cap_tmb_mon_morghast_archai' = $EFF_ARCH }
$effRows = @()
for ($r = 0; $r -lt $cnt; $r++) {
    $rowStart = $p
    $kl=[BitConverter]::ToUInt16($eb,$p); $p+=2; $key=[Text.Encoding]::UTF8.GetString($eb,$p,$kl); $p+=$kl
    $keyEnd = $p
    $f=$eb[$p]; $p++; if($f -eq 1){ $l=[BitConverter]::ToUInt16($eb,$p); $p+=2+$l }
    $p+=4
    $f=$eb[$p]; $p++; if($f -eq 1){ $l=[BitConverter]::ToUInt16($eb,$p); $p+=2+$l }
    $l=[BitConverter]::ToUInt16($eb,$p); $p+=2+$l
    $p+=1
    if ($effSrc.ContainsKey($key)) {
        $tail = $eb[$keyEnd..($p-1)]
        $effRows += ,([byte[]](New-CaString $effSrc[$key]) + [byte[]]$tail)
    }
}
if ($p -ne $eb.Length) { throw "effects reparse mismatch: $p/$($eb.Length)" }
if ($effRows.Count -ne 2) { throw "effect rows not found: $($effRows.Count)" }
$eff = New-TableHeader 2 0
foreach ($r in $effRows) { $eff += $r }
Write-Host "effects cloned: 2"

# ========== 6. effect_bonus_value_unit_record_junctions (no version): [bonus][effect][unit] ==========
$capJRows = @(
    @('unit_cap',$EFF_HARB,$HARB),
    @('unit_cap',$EFF_ARCH,$ARCH),
    # ghost-tech line buffs extended to morghasts
    @('battle_barrier_health','wh3_main_effect_barrier_health_cairn_wraith_hexwraith',$HARB),
    @('battle_barrier_health','wh3_main_effect_barrier_health_cairn_wraith_hexwraith',$ARCH),
    @('battle_healing_cap_mod','wh3_main_effect_healing_cap_wraiths',$HARB),
    @('battle_healing_cap_mod','wh3_main_effect_healing_cap_wraiths',$ARCH)
)
$capj = New-TableHeader $capJRows.Count 0
foreach ($r in $capJRows) { $capj += New-CaString $r[0]; $capj += New-CaString $r[1]; $capj += New-CaString $r[2] }

# ========== 7. building_effects_junction (no version): [bld][eff][scope][f32][f32][i32 0][s ""] ==========
$beRows = @(
    @('wh_main_vmp_forest_4', $EFF_HARB, 1.0),
    @('wh_main_vmp_forest_5', $EFF_HARB, 2.0),
    @('wh_main_vmp_forest_5', $EFF_ARCH, 1.0),
    @('wh3_dlc29_nag_necropolis_military_monsters_4', $EFF_HARB, 30.0),
    @('wh3_dlc29_nag_necropolis_military_monsters_4', $EFF_ARCH, 30.0),
    @('wh3_dlc29_nag_necropolis_military_monsters_5', $EFF_HARB, 30.0),
    @('wh3_dlc29_nag_necropolis_military_monsters_5', $EFF_ARCH, 30.0)
)
$be = New-TableHeader $beRows.Count 0
foreach ($r in $beRows) {
    $be += New-CaString $r[0]
    $be += New-CaString $r[1]
    $be += New-CaString 'building_to_faction_own'
    $be += [BitConverter]::GetBytes([single]$r[2])
    $be += [BitConverter]::GetBytes([single]$r[2])
    $be += [BitConverter]::GetBytes([int32]0)
    $be += New-CaString ''
}

# ========== 7b. technology_effects_junction (no version): [tech][effect][scope][f32] ==========
$teRows = @(
    @('wh3_main_tech_vmp_units_ghosts_2', $EFF_HARB, 1.0),
    @('wh3_main_tech_vmp_units_ghosts_3', $EFF_ARCH, 1.0)
)
$te = New-TableHeader $teRows.Count 0
foreach ($r in $teRows) {
    $te += New-CaString $r[0]
    $te += New-CaString $r[1]
    $te += New-CaString 'faction_to_faction_own_unseen'
    $te += [BitConverter]::GetBytes([single]$r[2])
}

# ========== 7c. Raise Dead (gravecall) pool entries ==========
$RD_POOL = 'wh3_dlc29_vmp_raise_dead_faction'
$VC_SUB = 'wh_main_sc_vmp_vampire_counts'

# mercenary_unit_groups v3: [f32 1.0][s group][i32 999999][s unit][i32 0xC8000000][i32 id][o absent]
$grpRows = @(
    @('vc_morghasts_grp_harbingers',$HARB,59001),
    @('vc_morghasts_grp_archai',$ARCH,59002)
)
$mug = New-TableHeader $grpRows.Count 3
foreach ($r in $grpRows) {
    $mug += [BitConverter]::GetBytes([single]1.0)
    $mug += New-CaString $r[0]
    $mug += [BitConverter]::GetBytes([int32]999999)
    $mug += New-CaString $r[1]
    $mug += [BitConverter]::GetBytes([int32]-939524096)
    $mug += [BitConverter]::GetBytes([int32]$r[2])
    $mug += [byte[]]@(0)
}

# mercenary_pool_to_groups_junctions v3: [s group][i32 999999][i32 id][s pool][o][o sub][o]
$pgRows = @(
    @('vc_morghasts_grp_harbingers',59003),
    @('vc_morghasts_grp_archai',59004)
)
$mpg = New-TableHeader $pgRows.Count 3
foreach ($r in $pgRows) {
    $mpg += New-CaString $r[0]
    $mpg += [BitConverter]::GetBytes([int32]999999)
    $mpg += [BitConverter]::GetBytes([int32]$r[1])
    $mpg += New-CaString $RD_POOL
    $mpg += [byte[]]@(0)
    $mpg += [byte[]]@(1); $mpg += New-CaString $VC_SUB
    $mpg += [byte[]]@(0)
}

# unit_recruitment_source_overrides (no version): [b 1][s cost][s unit][s pool]
$ovRows = @(@($HARB),@($ARCH))
$ov = New-TableHeader $ovRows.Count 0
foreach ($r in $ovRows) {
    $ov += [byte[]]@(1)
    $ov += New-CaString $r[0]
    $ov += New-CaString $r[0]
    $ov += New-CaString $RD_POOL
}

# resource_costs (no version): [s key][i32 0][RECRUITMENT][CANCELLED_RECRUITMENT][ARMY_UPKEEP][BACKGROUND_INCOME]
$rc = New-TableHeader 2 0
foreach ($k in @($HARB,$ARCH)) {
    $rc += New-CaString $k
    $rc += [BitConverter]::GetBytes([int32]0)
    $rc += New-CaString 'RECRUITMENT'
    $rc += New-CaString 'CANCELLED_RECRUITMENT'
    $rc += New-CaString 'ARMY_UPKEEP'
    $rc += New-CaString 'BACKGROUND_INCOME'
}

# resource_cost_pooled_resource_junctions v1: [i32 amount][s resource][s cost key][s absolute][s default]
$rcjRows = @(
    @(-1400,'wh3_dlc29_vmp_corpses_recruitment',$HARB),
    @(-450, 'wh3_dlc29_vmp_power_recruitment',  $HARB),
    @(-1500,'wh3_dlc29_vmp_corpses_recruitment',$ARCH),
    @(-550, 'wh3_dlc29_vmp_power_recruitment',  $ARCH)
)
$rcj = New-TableHeader $rcjRows.Count 1
foreach ($r in $rcjRows) {
    $rcj += [BitConverter]::GetBytes([int32]$r[0])
    $rcj += New-CaString $r[1]
    $rcj += New-CaString $r[2]
    $rcj += New-CaString 'absolute'
    $rcj += New-CaString 'default'
}

# ========== 8. loc file ==========
function New-LocString([string]$s) {
    $chars = $s.ToCharArray()
    return ,([BitConverter]::GetBytes([uint16]$chars.Length) + [Text.Encoding]::Unicode.GetBytes($s))
}
$locRows = @(
    @("effects_description_$EFF_HARB", "Unit capacity: %+n`nMorghast Harbingers"),
    @("effects_description_$EFF_ARCH", "Unit capacity: %+n`nMorghast Archai")
)
$loc = [byte[]]@(0xff,0xfe) + [Text.Encoding]::ASCII.GetBytes('LOC') + [byte[]]@(0) + [BitConverter]::GetBytes([uint32]1) + [BitConverter]::GetBytes([uint32]$locRows.Count)
foreach ($r in $locRows) { $loc += New-LocString $r[0]; $loc += New-LocString $r[1]; $loc += [byte[]]@(1) }

# ========== 9. assemble pack ==========
$files = @(
    @{ Path = "db\units_to_groupings_military_permissions_tables\!!!vc_morghasts"; Data = $perm },
    @{ Path = "db\building_units_allowed_tables\!!!vc_morghasts"; Data = $bld },
    @{ Path = "db\character_skill_nodes_tables\!!!vc_morghasts"; Data = $nodes },
    @{ Path = "db\unit_set_to_unit_junctions_tables\!!!vc_morghasts"; Data = $setj },
    @{ Path = "db\effects_tables\!!!vc_morghasts"; Data = $eff },
    @{ Path = "db\effect_bonus_value_unit_record_junctions_tables\!!!vc_morghasts"; Data = $capj },
    @{ Path = "db\building_effects_junction_tables\!!!vc_morghasts"; Data = $be },
    @{ Path = "db\technology_effects_junction_tables\!!!vc_morghasts"; Data = $te },
    @{ Path = "db\mercenary_unit_groups_tables\!!!vc_morghasts"; Data = $mug },
    @{ Path = "db\mercenary_pool_to_groups_junctions_tables\!!!vc_morghasts"; Data = $mpg },
    @{ Path = "db\unit_recruitment_source_overrides_tables\!!!vc_morghasts"; Data = $ov },
    @{ Path = "db\resource_costs_tables\!!!vc_morghasts"; Data = $rc },
    @{ Path = "db\resource_cost_pooled_resource_junctions_tables\!!!vc_morghasts"; Data = $rcj },
    @{ Path = "text\db\!!!vc_morghasts.loc"; Data = $loc }
)
$previewPath = "C:\Users\okolo\Downloads\vc-morghasts\preview.png"
if (Test-Path $previewPath) { $files += @{ Path = "vc_morghasts.png"; Data = [IO.File]::ReadAllBytes($previewPath) } }
$index = @(); $data = @()
foreach ($file in $files) {
    $nameBytes = [Text.Encoding]::ASCII.GetBytes($file.Path) + [byte]0
    $index += [BitConverter]::GetBytes([uint32]$file.Data.Length) + [byte[]]@(0) + $nameBytes
    $data += $file.Data
}
$header = [Text.Encoding]::ASCII.GetBytes("PFH5") + [BitConverter]::GetBytes([uint32]3) + [BitConverter]::GetBytes([uint32]0) + [BitConverter]::GetBytes([uint32]0) + [BitConverter]::GetBytes([uint32]$files.Count) + [BitConverter]::GetBytes([uint32]$index.Length) + [BitConverter]::GetBytes([uint32]0x7FFFFFFF)
$pack = $header + $index + $data
[IO.File]::WriteAllBytes("$scratch\vc_morghasts.pack", $pack)
Write-Host "pack built: $($pack.Length) bytes, $($files.Count) files"

# ========== 10. install ==========
$dataDir = "C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\data"
Copy-Item "$scratch\vc_morghasts.pack" "$dataDir\vc_morghasts.pack" -Force
$um = "C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\used_mods.txt"
$content = Get-Content $um -Raw
if ($content -notmatch 'vc_morghasts') { $content = $content.TrimEnd() + "`r`nmod `"vc_morghasts.pack`";`r`n"; [IO.File]::WriteAllText($um, $content, [Text.Encoding]::ASCII) }
Write-Host "installed"
