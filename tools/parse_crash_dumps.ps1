$ErrorActionPreference = 'Stop'
$dumps = Get-ChildItem "C:\Users\okolo\AppData\Roaming\The Creative Assembly\Warhammer3\crash_report" -Filter *.mdmp | Sort-Object LastWriteTime -Descending | Select-Object -First 5

foreach ($d in $dumps) {
    $b = [IO.File]::ReadAllBytes($d.FullName)
    if ([Text.Encoding]::ASCII.GetString($b,0,4) -ne 'MDMP') { Write-Host "$($d.Name): not MDMP"; continue }
    $numStreams = [BitConverter]::ToUInt32($b,8)
    $dirRva = [BitConverter]::ToUInt32($b,12)
    $excAddr = $null; $excCode = $null; $modBase = $null; $modSize = $null
    for ($i=0; $i -lt $numStreams; $i++) {
        $e = $dirRva + $i*12
        $type = [BitConverter]::ToUInt32($b,$e)
        $size = [BitConverter]::ToUInt32($b,$e+4)
        $rva  = [BitConverter]::ToUInt32($b,$e+8)
        if ($type -eq 6) {
            # ExceptionStream: ThreadId(4) align(4) ExceptionRecord{Code(4) Flags(4) Rec(8) Addr(8)...}
            $excCode = [BitConverter]::ToUInt32($b, $rva+8)
            $excAddr = [BitConverter]::ToUInt64($b, $rva+24)
        }
        if ($type -eq 4) {
            # ModuleListStream: u32 count; modules: Base(8) Size(4) Checksum(4) TimeDate(4) NameRva(4)...
            $cnt = [BitConverter]::ToUInt32($b,$rva)
            for ($m=0; $m -lt $cnt; $m++) {
                $mo = $rva + 4 + $m*108
                $base = [BitConverter]::ToUInt64($b,$mo)
                $msize = [BitConverter]::ToUInt32($b,$mo+8)
                $nameRva = [BitConverter]::ToUInt32($b,$mo+20)
                $nameLen = [BitConverter]::ToUInt32($b,$nameRva)
                $name = [Text.Encoding]::Unicode.GetString($b,$nameRva+4,$nameLen)
                if ($name -match 'Warhammer3\.exe$') { $modBase = $base; $modSize = $msize }
            }
        }
    }
    if ($excAddr -ne $null -and $modBase -ne $null) {
        $off = if ($excAddr -ge $modBase -and $excAddr -lt ($modBase+$modSize)) { '+0x{0:X}' -f ($excAddr-$modBase) } else { 'OUTSIDE exe' }
        Write-Host ("{0}: code=0x{1:X8} addr=0x{2:X} exeBase=0x{3:X} offset={4}" -f $d.Name, $excCode, $excAddr, $modBase, $off)
    } else {
        Write-Host ("{0}: exc={1} base={2}" -f $d.Name, $excAddr, $modBase)
    }
}
