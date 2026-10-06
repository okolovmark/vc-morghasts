param([Parameter(Mandatory)][UInt64]$Id, [Parameter(Mandatory)][string]$PackName, [uint32]$GameVersion = 589824, [string]$Note = "Added launcher metadata (PACK_NAME / game_version) so the classic CA launcher lists the mod.")
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir; [Environment]::CurrentDirectory = $dir
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SWU {
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_Init();
  [DllImport("steam_api64.dll")] public static extern void SteamAPI_Shutdown();
  [DllImport("steam_api64.dll")] public static extern void SteamAPI_RunCallbacks();
  [DllImport("steam_api64.dll")] public static extern IntPtr SteamAPI_SteamUGC_v017();
  [DllImport("steam_api64.dll")] public static extern IntPtr SteamAPI_SteamUtils_v010();
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, ref bool failed);
  [DllImport("steam_api64.dll")] public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, IntPtr buf, int size, int cbId, ref bool failed);
  [DllImport("steam_api64.dll")] public static extern ulong SteamAPI_ISteamUGC_StartItemUpdate(IntPtr self, uint appId, ulong id);
  [DllImport("steam_api64.dll", CharSet=CharSet.Ansi)] public static extern bool SteamAPI_ISteamUGC_AddItemKeyValueTag(IntPtr self, ulong h, string key, string value);
  [DllImport("steam_api64.dll", CharSet=CharSet.Ansi)] public static extern bool SteamAPI_ISteamUGC_RemoveItemKeyValueTags(IntPtr self, ulong h, string key);
  [DllImport("steam_api64.dll", CharSet=CharSet.Ansi)] public static extern ulong SteamAPI_ISteamUGC_SubmitItemUpdate(IntPtr self, ulong h, string note);
}
"@
if (-not [SWU]::SteamAPI_Init()) { throw "SteamAPI_Init failed" }
$ugc=[SWU]::SteamAPI_SteamUGC_v017(); $utils=[SWU]::SteamAPI_SteamUtils_v010()
$h=[SWU]::SteamAPI_ISteamUGC_StartItemUpdate($ugc,1142710,$Id)
"update handle=$h"
[void][SWU]::SteamAPI_ISteamUGC_RemoveItemKeyValueTags($ugc,$h,"PACK_NAME"); [void][SWU]::SteamAPI_ISteamUGC_RemoveItemKeyValueTags($ugc,$h,"game_version")
$a=[SWU]::SteamAPI_ISteamUGC_AddItemKeyValueTag($ugc,$h,"PACK_NAME",$PackName); $b=[SWU]::SteamAPI_ISteamUGC_AddItemKeyValueTag($ugc,$h,"game_version",$GameVersion.ToString())
"AddItemKeyValueTag PACK_NAME=$PackName -> $a ; game_version=$GameVersion -> $b"
$call=[SWU]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc,$h,$Note)
$failed=$false; $t=0
while(-not [SWU]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils,$call,[ref]$failed)){ [SWU]::SteamAPI_RunCallbacks(); Start-Sleep -Milliseconds 200; $t++; if($t -gt 600){ throw "timeout" } }
$rb=[Runtime.InteropServices.Marshal]::AllocHGlobal(64); $ok=[SWU]::SteamAPI_ISteamUtils_GetAPICallResult($utils,$call,$rb,64,3404,[ref]$failed)
$res=New-Object byte[] 64; [Runtime.InteropServices.Marshal]::Copy($rb,$res,0,64); [Runtime.InteropServices.Marshal]::FreeHGlobal($rb)
"SubmitItemUpdate: ok=$ok failed=$failed eresult=$([BitConverter]::ToInt32($res,0)) needsLegal=$($res[4]) id=$([BitConverter]::ToUInt64($res,8))"
[SWU]::SteamAPI_Shutdown()
