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

# ========== 6. VC unit caps = the ALLOWANCE system (owned-across-all-armies limit) ==========
# unit_allowances v1: [i32 base][s unit_list][o campaign_group]
$ua = New-TableHeader 2 1
foreach ($lst in @($HARB,$ARCH)) {
    $ua += [BitConverter]::GetBytes([int32]0)
    $ua += New-CaString $lst   # CA unit lists are keyed like the units
    $ua += [byte[]]@(1); $ua += New-CaString 'vampire_counts'
}
# effect_bonus_value_unit_list_junctions v0: [s unit_list][s effect][s bonus]
$capj = New-TableHeader 2 0
$capj += New-CaString $HARB; $capj += New-CaString $EFF_HARB; $capj += New-CaString 'unit_allowance_point_cap_mod'
$capj += New-CaString $ARCH; $capj += New-CaString $EFF_ARCH; $capj += New-CaString 'unit_allowance_point_cap_mod'

# ========== 7. building_effects_junction (no version): [bld][eff][scope][f32][f32][i32 0][s ""] ==========
$beRows = @(
    @('wh_main_vmp_forest_4', $EFF_HARB, 1.0),
    @('wh_main_vmp_forest_5', $EFF_HARB, 2.0),
    @('wh_main_vmp_forest_5', $EFF_ARCH, 1.0)
)
$be = New-TableHeader $beRows.Count 0
foreach ($r in $beRows) {
    $be += New-CaString $r[0]
    $be += New-CaString $r[1]
    $be += New-CaString 'faction_to_faction_own_unseen'
    $be += [BitConverter]::GetBytes([single]$r[2])
    $be += [BitConverter]::GetBytes([single]$r[2])
    $be += [BitConverter]::GetBytes([int32]0)
    $be += New-CaString ''
}

# ========== 7b. three custom technologies (Nagash pyramid buffs, minus gravecall) ==========
$T1 = 'vc_morghasts_tech_1'  # Harbingers
$T2 = 'vc_morghasts_tech_2'  # Archai
$T3 = 'vc_morghasts_tech_3'  # shared

# technologies v7: [key][building_level][i32 pos][icon][b][b][info_pic][i32 unique][b civil][b eng][b mil][b hidden]
$techRows = @(
    @($T1,'wh3_main_tech_vmp_units_terrorgheist_1',913370001),
    @($T2,'wh3_main_tech_vmp_units_terrorgheist_3',913370002),
    @($T3,'wh_main_vmp_fuelled_by_fear',913370003)
)
$tech = New-TableHeader $techRows.Count 7
foreach ($r in $techRows) {
    $tech += New-CaString $r[0]
    $tech += New-CaString 'wh_main_chs_port_ruin'
    $tech += [BitConverter]::GetBytes([int32]1)
    $tech += New-CaString $r[1]
    $tech += [byte[]]@(0,0)
    $tech += New-CaString '"placeholder.tga"'
    $tech += [BitConverter]::GetBytes([int32]$r[2])
    $tech += [byte[]]@(0,0,1,0)
}

# technology_nodes v0: [o camp][o fac][i32 indent][key][tech][node_set][i32 tier][i32 pts][i32 cpr][i32 food][o uig][o rcost][i32 reqpar][i32 px][i32 py]
$nodeRows = @(
    @($T1,7,100,'wh3_main_vmp_unit_tech_cost_600',30),
    @($T2,6,400,$null,15),
    @($T3,5,500,$null,0)
)
$UIG = 'vc_morghasts_ui_group'
$tnode = New-TableHeader $nodeRows.Count 0
foreach ($r in $nodeRows) {
    $tnode += [byte[]]@(0,0)
    $tnode += [BitConverter]::GetBytes([int32]$r[1])
    $tnode += New-CaString $r[0]
    $tnode += New-CaString $r[0]
    $tnode += New-CaString 'vmp_mil'
    $tnode += [BitConverter]::GetBytes([int32]46)
    $tnode += [BitConverter]::GetBytes([int32]$r[2])
    $tnode += [BitConverter]::GetBytes([int32]0)
    $tnode += [BitConverter]::GetBytes([int32]0)
    $tnode += [byte[]]@(1); $tnode += New-CaString $UIG
    if ($r[3]) { $tnode += [byte[]]@(1); $tnode += New-CaString $r[3] } else { $tnode += [byte[]]@(0) }
    $tnode += [BitConverter]::GetBytes([int32]0)
    $tnode += [BitConverter]::GetBytes([int32]120)
    $tnode += [BitConverter]::GetBytes([int32]$r[4])
}

# own UI group box: technology_ui_groups v6 [key][r][g][b][o bg]
$tuig = New-TableHeader 1 6
$tuig += New-CaString $UIG
$tuig += [BitConverter]::GetBytes([int32]160)
$tuig += [BitConverter]::GetBytes([int32]32)
$tuig += [BitConverter]::GetBytes([int32]240)
$tuig += [byte[]]@(0)

# groups junction v0: [top-right][group][bottom-left][o bottom-right][o top-left]
$tuigj = New-TableHeader 1 0
$tuigj += New-CaString $T1
$tuigj += New-CaString $UIG
$tuigj += New-CaString $T3
$tuigj += [byte[]]@(1); $tuigj += New-CaString $T3
$tuigj += [byte[]]@(1); $tuigj += New-CaString $T1

# technology_node_links v0: [child][i32 0][parent][i32 1][i32 3][i32 0][i32 0][b 1]
$linkRows = @(@($T2,$T1),@($T3,$T2))
$tlink = New-TableHeader $linkRows.Count 0
foreach ($r in $linkRows) {
    $tlink += New-CaString $r[0]
    $tlink += [BitConverter]::GetBytes([int32]0)
    $tlink += New-CaString $r[1]
    $tlink += [BitConverter]::GetBytes([int32]1)
    $tlink += [BitConverter]::GetBytes([int32]3)
    $tlink += [BitConverter]::GetBytes([int32]0)
    $tlink += [BitConverter]::GetBytes([int32]0)
    $tlink += [byte[]]@(1)
}

# technology_ui_tabs_to_technology_nodes_junctions v0: [node][tab]
$ttab = New-TableHeader 3 0
foreach ($t in @($T1,$T2,$T3)) { $ttab += New-CaString $t; $ttab += New-CaString 'vmp_units' }

# technology_effects_junction (no version): [tech][effect][scope][f32]
$FFO = 'faction_to_force_own'
$FFU = 'faction_to_faction_own_unseen'
$teRows = @(
    # T1 - Harbingers (pyramid values)
    @($T1,'wh3_dlc29_effect_force_stat_melee_defence_morghast_harbingers',$FFO,7.0),
    @($T1,'wh3_dlc29_effect_force_stat_bonus_vs_infantry_morghast_harbingers',$FFO,8.0),
    @($T1,'wh3_dlc29_effect_force_stat_weapon_strength_morghast_harbinger',$FFO,15.0),
    @($T1,'wh3_dlc29_effect_force_stat_ward_save_morghast_harbinger',$FFO,15.0),
    @($T1,'wh3_dlc29_effect_attribute_vanguard_deploy_morghast_harbingers',$FFO,1.0),
    @($T1,'wh3_dlc29_effect_force_stat_speed_morghast_harbingers',$FFO,15.0),
    @($T1,$EFF_HARB,$FFU,1.0),
    # T2 - Archai
    @($T2,'wh3_dlc29_effect_force_stat_armour_morghast_archai',$FFO,25.0),
    @($T2,'wh3_dlc29_effect_force_stat_bonus_vs_large_morghast_archai',$FFO,8.0),
    @($T2,'wh3_dlc29_effect_force_stat_weapon_strength_morghast_archai',$FFO,15.0),
    @($T2,'wh3_dlc29_effect_force_stat_leadership_morghast_archai',$FFO,15.0),
    @($T2,'wh3_dlc29_effect_force_stat_melee_attack_morghast_archai',$FFO,10.0),
    @($T2,'wh3_dlc29_effect_force_stat_ward_save_morghast_archai',$FFO,10.0),
    @($T2,$EFF_ARCH,$FFU,1.0),
    # T3 - shared
    @($T3,'wh3_dlc29_effect_force_attribute_enable_perfect_vigour_morghast',$FFO,1.0),
    @($T3,'wh3_dlc29_effect_ability_enable_heralds_of_the_accursed_one_morghast',$FFO,1.0),
    @($T3,'wh3_dlc29_effect_force_upkeep_morghasts',$FFO,-25.0)
)
$te = New-TableHeader $teRows.Count 0
foreach ($r in $teRows) {
    $te += New-CaString $r[0]
    $te += New-CaString $r[1]
    $te += New-CaString $r[2]
    $te += [BitConverter]::GetBytes([single]$r[3])
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
# elite units cost blood (vmp_power); priced like Blood Knights (620/660)
$rcjRows = @(
    @(-620, 'wh3_dlc29_vmp_power_recruitment',  $HARB),
    @(-660, 'wh3_dlc29_vmp_power_recruitment',  $ARCH)
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
    @("effects_description_$EFF_ARCH", "Unit capacity: %+n`nMorghast Archai"),
    @("technologies_onscreen_name_$T1", "Harbingers of the Accursed One"),
    @("technologies_short_description_$T1", "The Morghast Harbingers descend upon the Old World once more."),
    @("technologies_long_description_$T1", "In the Realm of Souls they were heralds of the Great Necromancer; now their blades serve the vampire courts."),
    @("technologies_onscreen_name_$T2", "Archai of the Great Necromancer"),
    @("technologies_short_description_$T2", "None shall withstand the might of the Archai."),
    @("technologies_long_description_$T2", "Clad in armour forged from amethyst magic itself, the Archai are death given form."),
    @("technologies_onscreen_name_$T3", "Heralds of the End Times"),
    @("technologies_short_description_$T3", "The Morghasts proclaim the coming of the end."),
    @("technologies_long_description_$T3", "Tireless and dreadful, the Morghasts herald the accursed one wherever the dead march."),
    @("technology_ui_groups_optional_display_name_$UIG", "Morghasts"),
    @("technology_ui_groups_optional_display_desctiption_$UIG", "Ancient constructs of the Great Necromancer")
)
$loc = [byte[]]@(0xff,0xfe) + [Text.Encoding]::ASCII.GetBytes('LOC') + [byte[]]@(0) + [BitConverter]::GetBytes([uint32]1) + [BitConverter]::GetBytes([uint32]$locRows.Count)
foreach ($r in $locRows) { $loc += New-LocString $r[0]; $loc += New-LocString $r[1]; $loc += [byte[]]@(1) }

# ========== 8b. Lua: inject raise-dead pool entries into existing saves ==========
$lua = @'
-- vc_morghasts: morghast entries for the VC Raise Dead pool.
-- Pool state is snapshotted into savegames, so db rows alone only affect
-- new campaigns; this registers the entries on load for existing saves too.
-- Entries are keyed (unit, source) and immutable once created, so re-running
-- is harmless.
local HARB = "wh3_dlc29_vmp_mon_morghast_harbingers"
local ARCH = "wh3_dlc29_vmp_mon_morghast_archai"
local SRC = "wh3_dlc29_vmp_raise_dead_faction"

cm:add_first_tick_callback(
	function()
		-- Stock is kept effectively unlimited; the real limit is the
		-- unit-allowance cap (owned across all armies), granted by the
		-- Haunted Wood buildings and the mod's technologies — the same
		-- mechanic every other VC unit uses.
		local function setup(faction)
			if faction:is_null_interface() then return end
			if faction:subculture() ~= "wh_main_sc_vmp_vampire_counts" then return end
			pcall(function()
				cm:add_unit_to_faction_mercenary_pool(
					faction, HARB, SRC,
					10, 100, 999999, 2, "", "", "", true, "vc_morghasts_grp_harbingers")
			end)
			pcall(function()
				cm:add_unit_to_faction_mercenary_pool(
					faction, ARCH, SRC,
					10, 100, 999999, 2, "", "", "", true, "vc_morghasts_grp_archai")
			end)
		end
		local factions = cm:model():world():faction_list()
		for i = 0, factions:num_items() - 1 do
			setup(factions:item_at(i))
		end
	end
)
'@

# ========== 9. assemble pack ==========
$files = @(
    @{ Path = "db\units_to_groupings_military_permissions_tables\!!!vc_morghasts"; Data = $perm },
    @{ Path = "db\building_units_allowed_tables\!!!vc_morghasts"; Data = $bld },
    @{ Path = "db\character_skill_nodes_tables\!!!vc_morghasts"; Data = $nodes },
    @{ Path = "db\unit_set_to_unit_junctions_tables\!!!vc_morghasts"; Data = $setj },
    @{ Path = "db\effects_tables\!!!vc_morghasts"; Data = $eff },
    @{ Path = "db\effect_bonus_value_unit_list_junctions_tables\!!!vc_morghasts"; Data = $capj },
    @{ Path = "db\unit_allowances_tables\!!!vc_morghasts"; Data = $ua },
    @{ Path = "db\building_effects_junction_tables\!!!vc_morghasts"; Data = $be },
    @{ Path = "db\technology_effects_junction_tables\!!!vc_morghasts"; Data = $te },
    @{ Path = "db\technologies_tables\!!!vc_morghasts"; Data = $tech },
    @{ Path = "db\technology_nodes_tables\!!!vc_morghasts"; Data = $tnode },
    @{ Path = "db\technology_node_links_tables\!!!vc_morghasts"; Data = $tlink },
    @{ Path = "db\technology_ui_tabs_to_technology_nodes_junctions_tables\!!!vc_morghasts"; Data = $ttab },
    @{ Path = "db\technology_ui_groups_tables\!!!vc_morghasts"; Data = $tuig },
    @{ Path = "db\technology_ui_groups_to_technology_nodes_junctions_tables\!!!vc_morghasts"; Data = $tuigj },
    @{ Path = "script\campaign\mod\vc_morghasts.lua"; Data = [Text.Encoding]::UTF8.GetBytes($lua) },
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
