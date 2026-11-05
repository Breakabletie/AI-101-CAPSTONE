<#
.SYNOPSIS
    Generates dummy satellite task logs in an Excel (.xlsx) file.

.DESCRIPTION
    Generates 300 satellite tracking tasks chronologically ordered within a 24-hour period.
    Fields included:
      - Task Number (integer 1..300)
      - Satellite Name (e.g. SIMSAT-01..20, with new unique satellites added each run)
      - SSC (5-digit integer, persistent per satellite)
      - SPUT (4-digit integer, 1000..9999)
      - Signal ID (positive ID at 20-35% rate, defaulting to 'neg')
      - Start time (HH:MM:SS)
      - Stop time (HH:MM:SS, allows overlapping task run times)
    
    Subsequent runs automatically advance the date to the next consecutive day (YYYY-MM-DD.xlsx)
    and add a random number of new unique satellites to the catalog.

.PARAMETER OutputDir
    Directory where the Excel files are written. Defaults to 'output'.

.PARAMETER StateFile
    Path to the JSON state file that tracks date, satellite catalog, and counters.
    Defaults to 'tools/satellite_state.json'.

.PARAMETER ExplicitDate
    Optional explicit date string (YYYY-MM-DD). If omitted, advances from previous run or starts at 2026-11-06.

.PARAMETER ResetState
    Switch to reset state back to Day 1 (20 satellites, 2026-11-06).
#>
param(
    [string]$OutputDir = "output",
    [string]$StateFile = "tools/satellite_state.json",
    [string]$ExplicitDate = "",
    [int]$TotalTasks = 300,
    [int]$InitialSatCount = 20,
    [int]$MinNewSats = 1,
    [int]$MaxNewSats = 4,
    [double]$MinSignalRate = 0.20,
    [double]$MaxSignalRate = 0.35,
    [switch]$ResetState
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# 1. State Management (date and persistent satellite catalog)
$state = $null
if ((Test-Path $StateFile) -and (-not $ResetState)) {
    try {
        $stateJson = Get-Content -LiteralPath $StateFile -Raw -Encoding utf8
        $state = ConvertFrom-Json $stateJson
    } catch {
        Write-Warning "Failed to parse existing state file ($StateFile). Starting fresh."
        $state = $null
    }
}

$rand = New-Object System.Random

if ($null -eq $state) {
    # Initialize fresh catalog with 20 satellites
    $targetDateStr = if ($ExplicitDate) { $ExplicitDate } else { "2026-11-06" }
    $sats = @()
    $baseSSC = 51000
    for ($i = 1; $i -le $InitialSatCount; $i++) {
        $sats += [PSCustomObject]@{
            Name = ("SIMSAT-{0:D2}" -f $i)
            SSC  = ($baseSSC + $i)
        }
    }
    $state = [PSCustomObject]@{
        LastDate        = $targetDateStr
        NextSatIndex    = $InitialSatCount + 1
        NextSignalIndex = 1001
        Satellites      = $sats
        RunCount        = 1
    }
    $newSatsAdded = 0
} else {
    # Subsequent run: advance date to next day
    $prevDate = [DateTime]::ParseExact($state.LastDate, "yyyy-MM-dd", $null)
    $nextDate = $prevDate.AddDays(1)
    $targetDateStr = if ($ExplicitDate) { $ExplicitDate } else { $nextDate.ToString("yyyy-MM-dd") }

    # Add a random number of new unique satellites
    $newSatCount = $rand.Next($MinNewSats, $MaxNewSats + 1)
    $currentSats = [System.Collections.ArrayList]@($state.Satellites)
    $nextIdx = [int]$state.NextSatIndex
    $baseSSC = 51000

    $newSatsList = @()
    for ($k = 0; $k -lt $newSatCount; $k++) {
        $satNum = $nextIdx + $k
        $newSat = [PSCustomObject]@{
            Name = ("SIMSAT-{0:D2}" -f $satNum)
            SSC  = ($baseSSC + $satNum)
        }
        [void]$currentSats.Add($newSat)
        $newSatsList += $newSat
    }

    $state.LastDate = $targetDateStr
    $state.NextSatIndex = $nextIdx + $newSatCount
    $state.Satellites = $currentSats.ToArray()
    $state.RunCount = [int]$state.RunCount + 1
    $newSatsAdded = $newSatCount
}

# 2. Determine signal detection count within 20% to 35%
$minSignals = [int][Math]::Ceiling($TotalTasks * $MinSignalRate)
$maxSignals = [int][Math]::Floor($TotalTasks * $MaxSignalRate)
$targetSignalCount = $rand.Next($minSignals, $maxSignals + 1)

$signalIndices = New-Object System.Collections.Generic.HashSet[int]
while ($signalIndices.Count -lt $targetSignalCount) {
    $idx = $rand.Next(0, $TotalTasks)
    [void]$signalIndices.Add($idx)
}

# 3. Generate Start Times (seconds within day 0..84600) and durations (5..35 minutes)
# Tasks are allowed to overlap in time. Chronologically ordered by Start time.
$maxStartSecond = 86400 - 1800 # Allow at least 30 minutes before midnight
$startSeconds = @()
for ($i = 0; $i -lt $TotalTasks; $i++) {
    $startSeconds += $rand.Next(0, $maxStartSecond)
}
$startSeconds = $startSeconds | Sort-Object

# 4. Build task list
$tasks = @()
$sigCounter = [int]$state.NextSignalIndex
$allSatellites = @($state.Satellites)

# If new satellites were added on this run, ensure every new satellite appears at least once
$guaranteedSats = [System.Collections.Generic.Queue[object]]::new()
if ($newSatsAdded -gt 0 -and $null -ne $newSatsList) {
    foreach ($ns in $newSatsList) {
        $guaranteedSats.Enqueue($ns)
    }
}

for ($i = 0; $i -lt $TotalTasks; $i++) {
    $taskNum = $i + 1
    
    # Assign satellite (inject guaranteed new satellites first, then uniform random)
    if ($guaranteedSats.Count -gt 0) {
        $sat = $guaranteedSats.Dequeue()
    } else {
        $sat = $allSatellites[$rand.Next(0, $allSatellites.Length)]
    }

    # SPUT: 4-digit integer (1000..9999)
    $sput = $rand.Next(1000, 10000)

    # Signal ID: rate between 20-35%, otherwise 'neg'
    if ($signalIndices.Contains($i)) {
        $signalId = "SIG-$sigCounter"
        $sigCounter++
    } else {
        $signalId = "neg"
    }

    # Start and Stop times formatted strictly as HH:MM:SS
    $startSec = $startSeconds[$i]
    $durationSec = $rand.Next(300, 2100) # 5 to 35 minutes pass
    $stopSec = $startSec + $durationSec
    if ($stopSec -ge 86400) {
        $stopSec = 86399 # clamp to 23:59:59
    }

    $startTimeStr = [TimeSpan]::FromSeconds($startSec).ToString("hh\:mm\:ss")
    $stopTimeStr  = [TimeSpan]::FromSeconds($stopSec).ToString("hh\:mm\:ss")

    $tasks += [PSCustomObject]@{
        TaskNumber = $taskNum
        SatName    = $sat.Name
        SSC        = $sat.SSC
        SPUT       = $sput
        SignalID   = $signalId
        StartTime  = $startTimeStr
        StopTime   = $stopTimeStr
    }
}

$state.NextSignalIndex = $sigCounter

# 5. Save updated state file
$stateDir = Split-Path -Parent $StateFile
if ($stateDir -and -not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
}
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StateFile -Encoding utf8

# 6. Build OpenXML Spreadsheet
$filesToZip = @{}

$filesToZip["[Content_Types].xml"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
'@

$filesToZip["_rels/.rels"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
'@

$filesToZip["xl/_rels/workbook.xml.rels"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
'@

$filesToZip["xl/workbook.xml"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Tasks" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
'@

$filesToZip["xl/styles.xml"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><name val="Calibri"/><sz val="11"/></font>
    <font><b/><color rgb="FFFFFFFF"/><name val="Calibri"/><sz val="11"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color rgb="FFD9D9D9"/></left>
      <right style="thin"><color rgb="FFD9D9D9"/></right>
      <top style="thin"><color rgb="FFD9D9D9"/></top>
      <bottom style="thin"><color rgb="FFD9D9D9"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
  </cellXfs>
</styleSheet>
'@

$headers = @("Task Number", "Satellite Name", "SSC", "SPUT", "Signal ID", "Start time", "Stop time")
$cols = @("A", "B", "C", "D", "E", "F", "G")

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
[void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
[void]$sb.AppendLine('  <cols>')
[void]$sb.AppendLine('    <col min="1" max="1" width="14" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="2" max="2" width="18" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="3" max="3" width="12" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="4" max="4" width="12" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="5" max="5" width="14" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="6" max="6" width="16" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="7" max="7" width="16" customWidth="1"/>')
[void]$sb.AppendLine('  </cols>')
[void]$sb.AppendLine('  <sheetData>')

# Header row
[void]$sb.AppendLine('    <row r="1" ht="24" customHeight="1">')
for ($c = 0; $c -lt $headers.Length; $c++) {
    $ref = "$($cols[$c])1"
    $val = [System.Security.SecurityElement]::Escape($headers[$c])
    [void]$sb.AppendLine("      <c r=`"$ref`" t=`"inlineStr`" s=`"1`"><is><t>$val</t></is></c>")
}
[void]$sb.AppendLine('    </row>')

# Data rows
for ($r = 0; $r -lt $tasks.Length; $r++) {
    $rowIdx = $r + 2
    $t = $tasks[$r]
    [void]$sb.AppendLine("    <row r=`"$rowIdx`">")
    
    # Task Number (numeric)
    [void]$sb.AppendLine("      <c r=`"A$rowIdx`" s=`"2`"><v>$($t.TaskNumber)</v></c>")
    # Satellite Name (string)
    $valB = [System.Security.SecurityElement]::Escape($t.SatName)
    [void]$sb.AppendLine("      <c r=`"B$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$valB</t></is></c>")
    # SSC (numeric 5-digit)
    [void]$sb.AppendLine("      <c r=`"C$rowIdx`" s=`"2`"><v>$($t.SSC)</v></c>")
    # SPUT (numeric 4-digit)
    [void]$sb.AppendLine("      <c r=`"D$rowIdx`" s=`"2`"><v>$($t.SPUT)</v></c>")
    # Signal ID (string)
    $valE = [System.Security.SecurityElement]::Escape($t.SignalID)
    [void]$sb.AppendLine("      <c r=`"E$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$valE</t></is></c>")
    # Start time (string HH:MM:SS)
    $valF = [System.Security.SecurityElement]::Escape($t.StartTime)
    [void]$sb.AppendLine("      <c r=`"F$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$valF</t></is></c>")
    # Stop time (string HH:MM:SS)
    $valG = [System.Security.SecurityElement]::Escape($t.StopTime)
    [void]$sb.AppendLine("      <c r=`"G$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$valG</t></is></c>")
    
    [void]$sb.AppendLine('    </row>')
}

[void]$sb.AppendLine('  </sheetData>')
[void]$sb.AppendLine('</worksheet>')

$filesToZip["xl/worksheets/sheet1.xml"] = $sb.ToString()

# 7. Package OpenXML XLSX
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}
$outputFileName = "$targetDateStr.xlsx"
$outputFile = Join-Path $OutputDir $outputFileName
$fullOutputPath = (Join-Path (Get-Location) $outputFile)

if (Test-Path $fullOutputPath) {
    Remove-Item -Force $fullOutputPath
}

$fileStream = New-Object System.IO.FileStream($fullOutputPath, [System.IO.FileMode]::Create)
$zipArchive = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($key in $filesToZip.Keys) {
    $entry = $zipArchive.CreateEntry($key, [System.IO.Compression.CompressionLevel]::Optimal)
    $entryStream = $entry.Open()
    $writer = New-Object System.IO.StreamWriter($entryStream, $utf8NoBom)
    $writer.Write($filesToZip[$key])
    $writer.Dispose()
    $entryStream.Dispose()
}

$zipArchive.Dispose()
$fileStream.Dispose()

# 8. Verification summary
$actualSignals = ($tasks | Where-Object { $_.SignalID -ne "neg" }).Count
$rate = ($actualSignals / $TotalTasks) * 100
$uniqueSatsInRun = ($tasks | Select-Object -ExpandProperty SatName -Unique).Count
$totalKnownSats = $state.Satellites.Count

Write-Host "=================================================="
Write-Host "Satellite Task List Generated Successfully"
Write-Host "=================================================="
Write-Host "File:                   $outputFile"
Write-Host "Date of tasks:          $targetDateStr"
Write-Host "Total Tasks:            $($tasks.Count)"
Write-Host "Unique Sats in File:    $uniqueSatsInRun"
Write-Host "Total Sats in Catalog:  $totalKnownSats (+$newSatsAdded new)"
Write-Host "Signal ID Count:        $actualSignals ($([Math]::Round($rate, 2))%)"
Write-Host "Earliest Start Time:    $($tasks[0].StartTime)"
Write-Host "Latest Stop Time:       $($tasks[-1].StopTime)"
Write-Host "Sample Task #1:         Sat=$($tasks[0].SatName), SSC=$($tasks[0].SSC), SPUT=$($tasks[0].SPUT), Sig=$($tasks[0].SignalID), Start=$($tasks[0].StartTime), Stop=$($tasks[0].StopTime)"
Write-Host "=================================================="
