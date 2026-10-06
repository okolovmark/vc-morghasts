param([string]$Ids = "3814064730,3789976964,3810991369,3029800597")
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir; [Environment]::CurrentDirectory = $dir
if (-not (Test-Path "$dir\steam_api64.dll")) { Copy-Item "C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\steam_api64.dll" $dir }
Set-Content -Path "$dir\steam_appid.txt" -Value "1142710" -NoNewline -Encoding Ascii

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SW {
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_Init();
  [DllImport("steam_api64.dll")] public static extern void SteamAPI_Shutdown();
  [DllImport("steam_api64.dll")] public static extern void SteamAPI_RunCallbacks();
  [DllImport("steam_api64.dll")] public static extern IntPtr SteamAPI_SteamUGC_v017();
  [DllImport("steam_api64.dll")] public static extern IntPtr SteamAPI_SteamUtils_v010();
  [DllImport("steam_api64.dll")] public static extern IntPtr SteamAPI_SteamUser_v023();
  [DllImport("steam_api64.dll")] public static extern ulong SteamAPI_ISteamUser_GetSteamID(IntPtr self);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUtils_GetAppID(IntPtr self);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, ref bool failed);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, IntPtr buf, int size, int cbId, ref bool failed);
  [DllImport("steam_api64.dll")] public static extern ulong SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(IntPtr self, uint acc, int list, int match, int sort, uint creator, uint consumer, uint page);
  [DllImport("steam_api64.dll")] public static extern ulong SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest(IntPtr self, ulong[] ids, uint n);
  [DllImport("steam_api64.dll")] public static extern ulong SteamAPI_ISteamUGC_SendQueryUGCRequest(IntPtr self, ulong h);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetQueryUGCResult(IntPtr self, ulong h, uint i, IntPtr details);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetQueryUGCNumTags(IntPtr self, ulong h, uint i);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetQueryUGCTag(IntPtr self, ulong h, uint i, uint t, byte[] buf, uint size);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(IntPtr self, ulong h);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetNumSubscribedItems(IntPtr self);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetSubscribedItems(IntPtr self, ulong[] ids, uint max);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetItemState(IntPtr self, ulong id);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_SetReturnMetadata(IntPtr self, ulong h, bool b);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_SetReturnKeyValueTags(IntPtr self, ulong h, bool b);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_SetReturnAdditionalPreviews(IntPtr self, ulong h, bool b);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetQueryUGCMetadata(IntPtr self, ulong h, uint i, byte[] buf, uint size);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetQueryUGCNumKeyValueTags(IntPtr self, ulong h, uint i);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetQueryUGCKeyValueTag(IntPtr self, ulong h, uint i, uint k, byte[] key, uint ks, byte[] val, uint vs);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetQueryUGCPreviewURL(IntPtr self, ulong h, uint i, byte[] buf, uint size);
  [DllImport("steam_api64.dll")] public static extern uint SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews(IntPtr self, ulong h, uint i);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUGC_GetItemInstallInfo(IntPtr self, ulong id, ref ulong size, byte[] folder, uint fs, ref uint ts);
}
"@

if (-not [SW]::SteamAPI_Init()) { throw "SteamAPI_Init failed (Steam running? steam_appid.txt?)" }
$ugc=[SW]::SteamAPI_SteamUGC_v017(); $utils=[SW]::SteamAPI_SteamUtils_v010(); $user=[SW]::SteamAPI_SteamUser_v023()
$sid=[SW]::SteamAPI_ISteamUser_GetSteamID($user); $acc=[uint32]([UInt64]$sid % [UInt64]4294967296)
"appid=$([SW]::SteamAPI_ISteamUtils_GetAppID($utils)) accountid=$acc"

function CStr($buf,$off,$len){ $s=[Text.Encoding]::UTF8.GetString($buf,$off,$len); $i=$s.IndexOf([char]0); if($i -ge 0){$s=$s.Substring(0,$i)}; return $s }
function RunQuery([UInt64]$h, [string]$label){
  [void][SW]::SteamAPI_ISteamUGC_SetReturnMetadata($ugc,$h,$true); [void][SW]::SteamAPI_ISteamUGC_SetReturnKeyValueTags($ugc,$h,$true); [void][SW]::SteamAPI_ISteamUGC_SetReturnAdditionalPreviews($ugc,$h,$true)
  $call=[SW]::SteamAPI_ISteamUGC_SendQueryUGCRequest($ugc,$h)
  $failed=$false; $t=0
  while(-not [SW]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils,$call,[ref]$failed)){ [SW]::SteamAPI_RunCallbacks(); Start-Sleep -Milliseconds 100; $t++; if($t -gt 300){ throw "timeout $label" } }
  $rb=[Runtime.InteropServices.Marshal]::AllocHGlobal(64); $ok=[SW]::SteamAPI_ISteamUtils_GetAPICallResult($utils,$call,$rb,64,3401,[ref]$failed)
  $res=New-Object byte[] 64; [Runtime.InteropServices.Marshal]::Copy($rb,$res,0,64); [Runtime.InteropServices.Marshal]::FreeHGlobal($rb)
  $eres=[BitConverter]::ToUInt32($res,8); $num=[BitConverter]::ToUInt32($res,12); $tot=[BitConverter]::ToUInt32($res,16)
  "=== $label : ok=$ok failed=$failed eresult=$eres returned=$num total=$tot"
  $db=[Runtime.InteropServices.Marshal]::AllocHGlobal(16384)
  for($i=0;$i -lt $num;$i++){
    if(-not [SW]::SteamAPI_ISteamUGC_GetQueryUGCResult($ugc,$h,[uint32]$i,$db)){ "  [$i] GetQueryUGCResult failed"; continue }
    $d=New-Object byte[] 16384; [Runtime.InteropServices.Marshal]::Copy($db,$d,0,16384)
    $id=[BitConverter]::ToUInt64($d,0); $r=[BitConverter]::ToInt32($d,8); $ft=[BitConverter]::ToInt32($d,12); $ca=[BitConverter]::ToUInt32($d,16); $co=[BitConverter]::ToUInt32($d,20)
    $title=CStr $d 24 129; $owner=[BitConverter]::ToUInt64($d,8160); $cr=[BitConverter]::ToUInt32($d,8168); $up=[BitConverter]::ToUInt32($d,8172); $added=[BitConverter]::ToUInt32($d,8176); $vis=[BitConverter]::ToInt32($d,8180)
    $banned=$d[8184]; $acc4u=$d[8185]; $ttr=$d[8186]; $tags=CStr $d 8187 1025; $fh=[BitConverter]::ToUInt64($d,9216); $ph=[BitConverter]::ToUInt64($d,9224); $fn=CStr $d 9232 260; $fs=[BitConverter]::ToInt32($d,9492); $ps=[BitConverter]::ToInt32($d,9496); $url=CStr $d 9500 256; $ch=[BitConverter]::ToUInt32($d,9768)
    $nt=[SW]::SteamAPI_ISteamUGC_GetQueryUGCNumTags($ugc,$h,[uint32]$i); $tl=@(); for($k=0;$k -lt $nt;$k++){ $tb=New-Object byte[] 256; [void][SW]::SteamAPI_ISteamUGC_GetQueryUGCTag($ugc,$h,[uint32]$i,[uint32]$k,$tb,256); $tl+=(CStr $tb 0 256) }
    $st=[SW]::SteamAPI_ISteamUGC_GetItemState($ugc,$id)
    $mb=New-Object byte[] 5000; [void][SW]::SteamAPI_ISteamUGC_GetQueryUGCMetadata($ugc,$h,[uint32]$i,$mb,5000); $meta=CStr $mb 0 5000
    $nkv=[SW]::SteamAPI_ISteamUGC_GetQueryUGCNumKeyValueTags($ugc,$h,[uint32]$i); $kvs=@(); for($k=0;$k -lt $nkv;$k++){ $kb=New-Object byte[] 256; $vb=New-Object byte[] 256; [void][SW]::SteamAPI_ISteamUGC_GetQueryUGCKeyValueTag($ugc,$h,[uint32]$i,[uint32]$k,$kb,256,$vb,256); $kvs+=("{0}={1}" -f (CStr $kb 0 256),(CStr $vb 0 256)) }
    $pb=New-Object byte[] 1024; [void][SW]::SteamAPI_ISteamUGC_GetQueryUGCPreviewURL($ugc,$h,[uint32]$i,$pb,1024); $purl=CStr $pb 0 1024
    $nap=[SW]::SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews($ugc,$h,[uint32]$i)
    $isz=[uint64]0; $its=[uint32]0; $fb=New-Object byte[] 1024; $ii=[SW]::SteamAPI_ISteamUGC_GetItemInstallInfo($ugc,$id,[ref]$isz,$fb,1024,[ref]$its); $ifold=CStr $fb 0 1024
    "      meta='$meta' kv=[$($kvs -join ';')] previewURL='$purl' addPreviews=$nap install: ok=$ii size=$isz ts=$its folder='$ifold'"
    "  [$i] id=$id result=$r fileType=$ft creatorApp=$ca consumerApp=$co vis=$vis banned=$banned acceptedForUse=$acc4u tagsTrunc=$ttr tags='$tags' numTags=$nt [$($tl -join ',')] fileHandle=$fh previewHandle=$ph filename='$fn' size=$fs previewSize=$ps url='$url' children=$ch itemState=$st owner=$owner created=$cr updated=$up added=$added title='$title'"
  }
  [Runtime.InteropServices.Marshal]::FreeHGlobal($db); [void][SW]::SteamAPI_ISteamUGC_ReleaseQueryUGCRequest($ugc,$h)
}

$n=[SW]::SteamAPI_ISteamUGC_GetNumSubscribedItems($ugc); $arr=New-Object UInt64[] 256; $got=[SW]::SteamAPI_ISteamUGC_GetSubscribedItems($ugc,$arr,256)
"GetNumSubscribedItems=$n GetSubscribedItems=$got : $(($arr[0..([Math]::Max(0,$got-1))]) -join ',')"

$idList = $Ids.Split(',') | ForEach-Object { [UInt64]$_ }
RunQuery ([SW]::SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest($ugc,[UInt64[]]$idList,[uint32]$idList.Count)) "Details($Ids)"
RunQuery ([SW]::SteamAPI_ISteamUGC_CreateQueryUserUGCRequest($ugc,$acc,6,2,4,1142710,1142710,1)) "Subscribed / Items_ReadyToUse / SubscriptionDateDesc"
RunQuery ([SW]::SteamAPI_ISteamUGC_CreateQueryUserUGCRequest($ugc,$acc,6,0,4,1142710,1142710,1)) "Subscribed / Items(0)"
RunQuery ([SW]::SteamAPI_ISteamUGC_CreateQueryUserUGCRequest($ugc,$acc,0,2,0,1142710,1142710,1)) "Published / Items_ReadyToUse"
RunQuery ([SW]::SteamAPI_ISteamUGC_CreateQueryUserUGCRequest($ugc,$acc,0,0,0,1142710,1142710,1)) "Published / Items(0)"
[SW]::SteamAPI_Shutdown()




