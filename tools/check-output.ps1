<#
.SYNOPSIS
    PowerShell native port of tools/check-output.sh for Windows environments.
.DESCRIPTION
    Scans a file for things that should not have survived sanitization:
    credentials, tokens, emails, phone numbers, SSNs, and unfilled placeholders.
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$File
)

if (-not (Test-Path $File)) {
    Write-Error "File not found: $File"
    exit 2
}

$findings = @()
$lines = Get-Content -LiteralPath $File

function Scan-Pattern([string]$label, [string]$pattern, [switch]$caseSensitive) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNum = $i + 1
        $lineText = $lines[$i]
        $match = if ($caseSensitive) {
            $lineText -cmatch $pattern
        } else {
            $lineText -match $pattern
        }
        if ($match) {
            $script:findings += [PSCustomObject]@{
                Label = $label
                Line  = $lineNum
                Text  = $lineText.Trim()
            }
        }
    }
}

# Credentials and keys
Scan-Pattern "possible credential" '(api[_-]?key|secret|passwd|password|token)\s*[:=]'
Scan-Pattern "key-shaped string"   '(AKIA|ghp_|sk-)[A-Za-z0-9]{8,}'

# Contact details
Scan-Pattern "email address"       '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
Scan-Pattern "phone-shaped number" '\b(\+?1[-. ])?\(?[0-9]{3}\)?[-. ][0-9]{3}[-. ][0-9]{4}\b'
Scan-Pattern "SSN-shaped number"   '\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b'

# Unfilled placeholders
Scan-Pattern "unfilled placeholder" '\[(NAME|ID|ORG|DATE|REDACTED)\]|TODO|FIXME|XXX'

Write-Host "Scanning $File"
Write-Host ""

if ($findings.Count -gt 0) {
    foreach ($f in $findings) {
        Write-Host ("  {0,-22} line {1}: {2}" -f $f.Label, $f.Line, $f.Text)
    }
    Write-Host ""
    Write-Host "Findings above. Resolve them, then run the four checks in AGENTS.md."
    exit 1
}

Write-Host "No obvious findings."
Write-Host "This does NOT clear the file. Run the four checks in AGENTS.md before it moves to output/."
exit 0
