$ErrorActionPreference = 'Stop'
$s = "C:\Users\okolo\AppData\Local\Temp\claude\C--Program-Files--x86--Steam-steamapps-common-Total-War-WARHAMMER-III\3bda4f82-c64b-4f39-8a87-f75b557a77f7\scratchpad"
$b = [IO.File]::ReadAllBytes("$s\vc_morghasts.pack")
$fc=[BitConverter]::ToUInt32($b,16); $is=[BitConverter]::ToUInt32($b,20); $p=28; $off=28+$is
function RS([byte[]]$b,[ref]$p){ $len=[BitConverter]::ToUInt16($b,$p.Value); $p.Value+=2; $s=[Text.Encoding]::UTF8.GetString($b,$p.Value,$len); $p.Value+=$len; return $s }
for($i=0;$i -lt $fc;$i++){ $sz=[BitConverter]::ToUInt32($b,$p); $p+=5; $e=$p; while($b[$e] -ne 0){$e++}; $nm=[Text.Encoding]::ASCII.GetString($b,$p,$e-$p); $p=$e+1
  Write-Host "== $nm ($sz bytes)"
  $t = $b[$off..($off+$sz-1)]; $off+=$sz
  if ($nm -like 'text*') {
    $q=10; $cnt=[BitConverter]::ToUInt32($t,$q-4)
    $cnt=[BitConverter]::ToUInt32($t,6)
    $q=10
    for($r=0;$r -lt $cnt;$r++){ $kl=[BitConverter]::ToUInt16($t,$q); $q+=2; $k=[Text.Encoding]::Unicode.GetString($t,$q,$kl*2); $q+=$kl*2; $tl=[BitConverter]::ToUInt16($t,$q); $q+=2; $tx=[Text.Encoding]::Unicode.GetString($t,$q,$tl*2); $q+=$tl*2; $tip=$t[$q]; $q++; Write-Host "   [$k] = [$($tx -replace "`n",' / ')] tip=$tip" }
    if ($q -ne $t.Length) { Write-Host "   !! LOC MISMATCH $q/$($t.Length)" } else { Write-Host "   EOF OK" }
    continue
  }
  $q=0
  if ($t[0] -eq 0xfd) { $gl=[BitConverter]::ToUInt16($t,4); $q=6+$gl*2 }
  if ($t[$q] -eq 0xfc) { Write-Host ("   version={0}" -f [BitConverter]::ToInt32($t,$q+4)); $q+=8 }
  $q+=1; $cnt=[BitConverter]::ToUInt32($t,$q); $q+=4
  Write-Host "   rows=$cnt"
  $rq=[ref]$q
  for($r=0;$r -lt $cnt;$r++){
    switch -Wildcard ($nm) {
      '*groupings*' { $u=RS $t $rq; $g=RS $t $rq; Write-Host "   [$u] -> [$g]" }
      '*building_units*' { $bl=RS $t $rq; $u=RS $t $rq; $q+=14; $rq=[ref]$q; Write-Host "   [$bl] -> [$u]" }
      '*skill_nodes*' { $f=$t[$q];$q++; if($f -eq 1){$rq=[ref]$q; $null=RS $t $rq}; $rq=[ref]$q; $sk=RS $t $rq; $f=$t[$q];$q++; if($f -eq 1){$rq=[ref]$q;$null=RS $t $rq}; $q+=4; $rq=[ref]$q; $k=RS $t $rq; $q+=4; $f=$t[$q];$q++; $sub='<none>'; if($f -eq 1){$rq=[ref]$q;$sub=RS $t $rq}; $q+=9; $rq=[ref]$q; Write-Host "   key=[$k] skill=[$sk] sub=$sub" }
      '*unit_set_to_unit*' { $q+=1; $flags=@(); for($j=0;$j -lt 4;$j++){ $f=$t[$q];$q++; if($f -eq 1){ $rq=[ref]$q; $flags += (RS $t $rq); $q=$rq.Value } }; $rq=[ref]$q; $set=RS $t $rq; $q=$rq.Value; Write-Host "   [$($flags -join ',')] -> set [$set]" }
      'db\effects_tables*' { $rq=[ref]$q; $k=RS $t $rq; $q=$rq.Value; $f=$t[$q];$q++; $ic='<none>'; if($f -eq 1){$rq=[ref]$q;$ic=RS $t $rq;$q=$rq.Value}; $pri=[BitConverter]::ToInt32($t,$q); $q+=4; $f=$t[$q];$q++; if($f -eq 1){$rq=[ref]$q;$null=RS $t $rq;$q=$rq.Value}; $rq=[ref]$q; $cat=RS $t $rq; $q=$rq.Value; $bb=$t[$q]; $q++; Write-Host "   effect=[$k] icon=[$ic] i32=$pri cat=[$cat] b=$bb" }
      '*unit_record*' { $rq=[ref]$q; $bo=RS $t $rq; $ef=RS $t $rq; $un=RS $t $rq; $q=$rq.Value; Write-Host "   [$bo] [$ef] -> [$un]" }
      '*building_effects*' { $rq=[ref]$q; $bl=RS $t $rq; $ef=RS $t $rq; $sc=RS $t $rq; $q=$rq.Value; $v1=[BitConverter]::ToSingle($t,$q); $q+=4; $v2=[BitConverter]::ToSingle($t,$q); $q+=4; $q+=4; $rq=[ref]$q; $cond=RS $t $rq; $q=$rq.Value; Write-Host "   [$bl] [$ef] scope=[$sc] v=$v1/$v2 cond=[$cond]" }
    }
    $q=$rq.Value
  }
  if ($q -ne $t.Length) { Write-Host "   !! PARSE MISMATCH $q/$($t.Length)" } else { Write-Host "   EOF OK" }
}
