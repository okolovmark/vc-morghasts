param([string]$File, [int]$MaxLen = 7)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class GBrute {
    public static int HeaderEnd(byte[] b) {
        int p = 0;
        if (b[0] == 0xfd) { int gl = BitConverter.ToUInt16(b, 4); p = 6 + gl*2; }
        if (b[p] == 0xfc) p += 8;
        p += 1;
        return p; // count follows
    }
    public static bool TryParse(byte[] b, string g, int dataStart, uint count) {
        long p = dataStart;
        long len = b.Length;
        for (uint r = 0; r < count; r++) {
            foreach (char t in g) {
                switch (t) {
                    case 's': {
                        if (p + 2 > len) return false;
                        int l = BitConverter.ToUInt16(b, (int)p); p += 2 + l;
                        break; }
                    case 'o': {
                        if (p + 1 > len) return false;
                        byte f = b[p]; p += 1;
                        if (f == 1) { if (p + 2 > len) return false; int l = BitConverter.ToUInt16(b, (int)p); p += 2 + l; }
                        else if (f != 0) return false;
                        break; }
                    case 'i': p += 4; break;
                    case 'b': p += 1; break;
                    case 'h': p += 2; break;
                }
                if (p > len) return false;
            }
        }
        return p == len;
    }
    public static List<string> Search(byte[] b, int maxLen) {
        int hp = HeaderEnd(b);
        uint count = BitConverter.ToUInt32(b, hp);
        int dataStart = hp + 4;
        var results = new List<string>();
        char[] alphabet = new char[] { 's', 'o', 'i', 'b', 'h' };
        var queue = new Queue<string>();
        queue.Enqueue("");
        while (queue.Count > 0) {
            string g = queue.Dequeue();
            if (g.Length > 0 && TryParse(b, g, dataStart, count)) results.Add(g);
            if (g.Length < maxLen) foreach (char c in alphabet) queue.Enqueue(g + c);
        }
        return results;
    }
}
'@
$b = [IO.File]::ReadAllBytes($File)
$res = [GBrute]::Search($b, $MaxLen)
Write-Host "File: $(Split-Path $File -Leaf)"
foreach ($g in $res) { Write-Host "  MATCH: '$g'" }
if ($res.Count -eq 0) { Write-Host "  no match up to length $MaxLen" }
