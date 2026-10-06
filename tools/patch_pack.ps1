param([string]$In, [string]$Out, [string[]]$DropPatterns = @(), [switch]$AddAllowance, [switch]$DropUnitCap, [switch]$VanillaScope)
$ErrorActionPreference = 'Stop'
function New-CaString([string]$x){ $bb=[Text.Encoding]::UTF8.GetBytes($x); return ,([BitConverter]::GetBytes([uint16]$bb.Length)+$bb) }
function New-TableHeader([int]$rc,[int]$ver){ $g=[Guid]::NewGuid().ToString(); $h=[byte[]]@(0xfd,0xfe,0xfc,0xff)+[BitConverter]::GetBytes([uint16]$g.Length)+[Text.Encoding]::Unicode.GetBytes($g); if($ver -gt 0){$h+=[byte[]]@(0xfc,0xfd,0xfe,0xff)+[BitConverter]::GetBytes([int32]$ver)}; $h+=[byte[]]@(1)+[BitConverter]::GetBytes([uint32]$rc); return ,$h }

$HARB='wh3_dlc29_vmp_mon_morghast_harbingers'; $ARCH='wh3_dlc29_vmp_mon_morghast_archai'
$EFF_HARB='vc_morghasts_unit_cap_harbingers'; $EFF_ARCH='vc_morghasts_unit_cap_archai'
$LIST_HARB='vc_morghasts_cap_harbingers'; $LIST_ARCH='vc_morghasts_cap_archai'

$b = [IO.File]::ReadAllBytes($In)
$fc=[BitConverter]::ToUInt32($b,16); $is=[BitConverter]::ToUInt32($b,20); $p=28; $off=[long](28+$is); $entries=@()
for($i=0;$i -lt $fc;$i++){ $sz=[BitConverter]::ToUInt32($b,$p); $p+=5; $e=$p; while($b[$e] -ne 0){$e++}; $nm=[Text.Encoding]::ASCII.GetString($b,$p,$e-$p); $p=$e+1; $entries += [PSCustomObject]@{Name=$nm;Data=$b[$off..($off+$sz-1)]}; $off+=$sz }

foreach($pat in $DropPatterns){ $entries = $entries | Where-Object { $_.Name -notmatch $pat } }
if ($DropUnitCap) { $entries = $entries | Where-Object { $_.Name -notmatch 'effect_bonus_value_unit_record' } }

if ($VanillaScope) {
    # building_effects_junction: only the 3 Haunted Wood rows, vanilla cap scope
    $beRows=@(@('wh_main_vmp_forest_4',$EFF_HARB,1.0),@('wh_main_vmp_forest_5',$EFF_HARB,2.0),@('wh_main_vmp_forest_5',$EFF_ARCH,1.0))
    $be = New-TableHeader $beRows.Count 0
    foreach($r in $beRows){ $be+=New-CaString $r[0]; $be+=New-CaString $r[1]; $be+=New-CaString 'faction_to_faction_own_unseen'; $be+=[BitConverter]::GetBytes([single]$r[2]); $be+=[BitConverter]::GetBytes([single]$r[2]); $be+=[BitConverter]::GetBytes([int32]0); $be+=New-CaString '' }
    foreach($en in $entries){ if($en.Name -match 'building_effects_junction'){ $en.Data = $be } }
}

if ($AddAllowance) {
    $ul = New-TableHeader 2 0; $ul += New-CaString $LIST_ARCH; $ul += New-CaString $LIST_HARB
    $ulj = New-TableHeader 2 0; $ulj += New-CaString $HARB; $ulj += New-CaString $LIST_HARB; $ulj += New-CaString $ARCH; $ulj += New-CaString $LIST_ARCH
    $ua = New-TableHeader 2 1
    foreach($lst in @($LIST_HARB,$LIST_ARCH)){ $ua += [BitConverter]::GetBytes([int32]0); $ua += New-CaString $lst; $ua += [byte[]]@(1); $ua += New-CaString 'vampire_counts' }
    $capj = New-TableHeader 2 0
    $capj += New-CaString 'unit_allowance_point_cap_mod'; $capj += New-CaString $LIST_HARB; $capj += New-CaString $EFF_HARB
    $capj += New-CaString 'unit_allowance_point_cap_mod'; $capj += New-CaString $LIST_ARCH; $capj += New-CaString $EFF_ARCH
    $entries += [PSCustomObject]@{Name='db\unit_lists_tables\!!!vc_morghasts';Data=$ul}
    $entries += [PSCustomObject]@{Name='db\unit_to_unit_list_junctions_tables\!!!vc_morghasts';Data=$ulj}
    $entries += [PSCustomObject]@{Name='db\unit_allowances_tables\!!!vc_morghasts';Data=$ua}
    $entries += [PSCustomObject]@{Name='db\effect_bonus_value_unit_list_junctions_tables\!!!vc_morghasts';Data=$capj}
}

function Flat($a){ $o=New-Object System.Collections.Generic.List[byte]; foreach($x in $a){ if($x -is [array]){ foreach($y in (Flat $x)){ $o.Add($y) } } else { $o.Add([byte]$x) } }; return ,$o.ToArray() }
foreach($f in $entries){ $f.Data = Flat $f.Data }
$ms = New-Object IO.MemoryStream
$idx = New-Object IO.MemoryStream
foreach($f in $entries){ $nb=[Text.Encoding]::ASCII.GetBytes($f.Name); $idx.Write([BitConverter]::GetBytes([uint32]$f.Data.Length),0,4); $idx.WriteByte(0); $idx.Write($nb,0,$nb.Length); $idx.WriteByte(0) }
$ib=$idx.ToArray()
$hdr = Flat @([Text.Encoding]::ASCII.GetBytes("PFH5"),[BitConverter]::GetBytes([uint32]3),[BitConverter]::GetBytes([uint32]0),[BitConverter]::GetBytes([uint32]0),[BitConverter]::GetBytes([uint32]$entries.Count),[BitConverter]::GetBytes([uint32]$ib.Length),[BitConverter]::GetBytes([uint32]0x7FFFFFFF))
$ms.Write($hdr,0,$hdr.Length)
$ms.Write($ib,0,$ib.Length)
foreach($f in $entries){ $ms.Write($f.Data,0,$f.Data.Length) }
$outBytes=$ms.ToArray()
[IO.File]::WriteAllBytes($Out,$outBytes)
Write-Host "written $Out : $($outBytes.Length) bytes, $($entries.Count) files"
$entries | ForEach-Object { Write-Host "  $($_.Name)" }
