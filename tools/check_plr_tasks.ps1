<#
.SYNOPSIS
    Post-Launch Requirements (PLR) Task Log Verification Program.

.DESCRIPTION
    Ingests a satellite mission task log and compares it against post-launch requirements.
    Creates or updates the post_launch_requirements.xlsx document with color-coded status.
    Prompts the operator when new Signal IDs are discovered for the first time on a satellite.

    Color Logic:
      SIG ID Box:
        RED   (default)  — satellite has never had a signal ID detected.
        GREEN (achieved) — a signal ID was found; box shows operator's name.
      Operator Confirm Next Requirement Completed Box:
        WHITE (default)  — no signal ID yet; not applicable.
        RED   (pending)  — signal ID found but operator has NOT confirmed follow-on.
        GREEN (complete) — operator confirmed subsequent requirements are done.
      Start/End Time:
        Blank until a SIG ID is found; then updated to the most recent pass times.

.PARAMETER TaskLogPath
    Path to the satellite task log Excel file (e.g. output/2026-11-06.xlsx).

.PARAMETER PlrDocPath
    Path to the PLR tracking Excel file. Created if it does not exist.
    Defaults to output/post_launch_requirements.xlsx.

.PARAMETER OperatorName
    Callsign or name of the operator running the tool.

.PARAMETER NonInteractive
    Skip Read-Host prompts (for automated testing). Uses DefaultConfirmation.

.PARAMETER DefaultConfirmation
    Default answer when NonInteractive is set ("y" or "n"). Defaults to "y".
#>
param(
    [string]$TaskLogPath,
    [string]$PlrDocPath = "output/post_launch_requirements.xlsx",
    [string]$OperatorName,
    [switch]$NonInteractive,
    [string]$DefaultConfirmation = "y"
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ── Helper: read sheet1.xml out of an xlsx ──────────────────────────
function Read-SheetXml([string]$xlsxPath) {
    $fullPath = (Resolve-Path $xlsxPath).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($fullPath)
    $entry = $zip.GetEntry('xl/worksheets/sheet1.xml')
    if (-not $entry) { $zip.Dispose(); throw "Missing xl/worksheets/sheet1.xml in $xlsxPath" }
    $stream = $entry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    $xmlText = $reader.ReadToEnd()
    $reader.Dispose(); $stream.Dispose(); $zip.Dispose()
    return [xml]$xmlText
}

# ── Helper: cell value from inline-string or <v> ────────────────────
function Get-CellValue($cell) {
    if ($cell.is)     { return $cell.is.t }
    elseif ($cell.v)  { return $cell.v }
    else              { return "" }
}

# ── 1. Interactive prompts for missing inputs ───────────────────────
if (-not $TaskLogPath) {
    $searchDir = "output"
    $taskFiles = @()
    if (Test-Path $searchDir) {
        $taskFiles = Get-ChildItem -Path $searchDir -Filter "*.xlsx" |
            Where-Object { $_.Name -notmatch "post_launch_requirements" -and $_.Name -notmatch "^\~\$" } |
            Sort-Object Name -Descending
    }

    if ($taskFiles.Count -gt 0) {
        Write-Host "Available Satellite Task Logs in '$searchDir/':" -ForegroundColor Cyan
        for ($i = 0; $i -lt $taskFiles.Count; $i++) {
            $f = $taskFiles[$i]
            $tag = if ($i -eq 0) { " (Latest)" } else { "" }
            Write-Host ("  [{0}] {1}{2}  (Modified: {3:yyyy-MM-dd HH:mm:ss})" -f ($i + 1), $f.Name, $tag, $f.LastWriteTime)
        }
        Write-Host "  [C] Enter custom file path"
        Write-Host ""

        $selection = Read-Host ("Select task log number [1-{0}, default: 1]" -f $taskFiles.Count)
        if ([string]::IsNullOrWhiteSpace($selection) -or $selection -eq "1") {
            $TaskLogPath = $taskFiles[0].FullName
            Write-Host "Selected: $TaskLogPath" -ForegroundColor Green
        } elseif ($selection -match '^[cC]$') {
            $TaskLogPath = Read-Host "Enter path to Satellite Task Log Excel file"
        } elseif ($selection -match '^\d+$' -and [int]$selection -le $taskFiles.Count -and [int]$selection -ge 1) {
            $TaskLogPath = $taskFiles[[int]$selection - 1].FullName
            Write-Host "Selected: $TaskLogPath" -ForegroundColor Green
        } else {
            $TaskLogPath = $selection
        }
    } else {
        $TaskLogPath = Read-Host "Enter path to Satellite Task Log Excel file"
    }
}
while (-not (Test-Path $TaskLogPath)) {
    Write-Warning "File not found: $TaskLogPath"
    $TaskLogPath = Read-Host "Please enter a valid path to the Satellite Task Log"
}

if (-not $OperatorName) {
    if ($NonInteractive) { $OperatorName = "OPERATOR_01" }
    else {
        $OperatorName = Read-Host "Enter Operator Name/Callsign"
        if ([string]::IsNullOrWhiteSpace($OperatorName)) { $OperatorName = "OPERATOR_01" }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Post-Launch Requirements (PLR) Verification Program      " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Task Log:    $TaskLogPath"
Write-Host "  PLR Doc:     $PlrDocPath"
Write-Host "  Operator:    $OperatorName"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 2. Load or initialise in-memory PLR records ────────────────────
# Each value is a plain hashtable so properties are freely mutable.
$plrRecords = @{}   # keyed by SSC (int)

if (Test-Path $PlrDocPath) {
    Write-Host "[INFO] Loading existing PLR document: $PlrDocPath" -ForegroundColor Yellow
    try {
        $plrDoc = Read-SheetXml $PlrDocPath
        $plrRows = $plrDoc.worksheet.sheetData.row
        for ($r = 1; $r -lt $plrRows.Count; $r++) {
            $c = $plrRows[$r].c
            $ssc       = [int](Get-CellValue $c[0])
            $satName   = Get-CellValue $c[1]
            $sput      = [int](Get-CellValue $c[2])
            $sigBox    = Get-CellValue $c[3]
            $confBox   = Get-CellValue $c[4]
            $startVal  = Get-CellValue $c[5]
            $stopVal   = Get-CellValue $c[6]

            $hasSig    = ($sigBox -ne "NO SIGNAL" -and -not [string]::IsNullOrWhiteSpace($sigBox))

            $plrRecords[$ssc] = @{
                SSC           = $ssc
                SatName       = $satName
                SPUT          = $sput
                HasSigId      = $hasSig
                SigIdBoxText  = $sigBox
                ConfirmStatus = $confBox   # "CONFIRMED COMPLETED", "PENDING CONFIRMATION", ""
                StartTime     = $startVal
                EndTime       = $stopVal
            }
        }
        Write-Host "  Loaded $($plrRecords.Count) satellite records." -ForegroundColor Green
    } catch {
        Write-Warning "  Could not parse existing PLR file - starting fresh."
        $plrRecords = @{}
    }
} else {
    Write-Host "[INFO] PLR document not found. A new one will be created." -ForegroundColor Cyan
}

# ── 3. Read task log ────────────────────────────────────────────────
Write-Host "[INFO] Reading task log..." -ForegroundColor Yellow
$taskDoc  = Read-SheetXml $TaskLogPath
$taskRows = $taskDoc.worksheet.sheetData.row
$taskCount = $taskRows.Count - 1
Write-Host "  $taskCount tasks found." -ForegroundColor Green
Write-Host ""

$tasks = @()
for ($r = 1; $r -lt $taskRows.Count; $r++) {
    $c = $taskRows[$r].c
    $tasks += @{
        TaskNum   = [int](Get-CellValue $c[0])
        SatName   = Get-CellValue $c[1]
        SSC       = [int](Get-CellValue $c[2])
        SPUT      = [int](Get-CellValue $c[3])
        SignalID  = Get-CellValue $c[4]
        StartTime = Get-CellValue $c[5]
        StopTime  = Get-CellValue $c[6]
    }
}

# ── 4. Compare every task against PLR records ───────────────────────
$newCount     = 0
$updateCount  = 0

foreach ($t in $tasks) {
    $ssc = $t.SSC

    # Ensure an entry exists for this satellite
    if (-not $plrRecords.ContainsKey($ssc)) {
        $plrRecords[$ssc] = @{
            SSC           = $ssc
            SatName       = $t.SatName
            SPUT          = $t.SPUT
            HasSigId      = $false
            SigIdBoxText  = "NO SIGNAL"
            ConfirmStatus = ""
            StartTime     = ""
            EndTime       = ""
        }
    }

    $rec = $plrRecords[$ssc]
    if ([string]::IsNullOrEmpty($rec.SatName)) { $rec.SatName = $t.SatName }

    $hasSig = ($t.SignalID -and $t.SignalID -ne "neg" -and $t.SignalID -ne "NO SIGNAL")

    if ($hasSig) {
        if (-not $rec.HasSigId) {
            # ---- FIRST SIG ID for this satellite - critical alert ----
            $newCount++
            Write-Host ""
            Write-Host "======================================================================" -ForegroundColor Magenta
            Write-Host "  ** NEW SIGNAL ID DETECTED - PLR REQUIREMENT MET **" -ForegroundColor Yellow
            Write-Host "======================================================================" -ForegroundColor Magenta
            $msgTask  = "  Task Number:    #$($t.TaskNum)"
            $msgSat   = "  Satellite:      $($t.SatName)"
            $msgSSC   = "  SSC:            $($t.SSC)"
            $msgSPUT  = "  SPUT:           $($t.SPUT)"
            $msgSig   = "  Signal ID:      $($t.SignalID)"
            $msgStart = "  Start Time:     $($t.StartTime)"
            $msgStop  = "  Stop Time:      $($t.StopTime)"
            Write-Host $msgTask
            Write-Host $msgSat
            Write-Host $msgSSC
            Write-Host $msgSPUT
            Write-Host $msgSig -ForegroundColor Green
            Write-Host $msgStart
            Write-Host $msgStop
            Write-Host "----------------------------------------------------------------------"

            # Prompt operator
            $confirmed = $false
            if ($NonInteractive) {
                $confirmed = ($DefaultConfirmation -match '^[yY]')
                Write-Host "  [AUTO] Subsequent-requirements confirmation: $DefaultConfirmation" -ForegroundColor DarkGray
            } else {
                $answer = Read-Host "  Have subsequent mission requirements been completed? (y/n)"
                $confirmed = ($answer -match '^[yY]')
            }

            $rec.HasSigId     = $true
            $rec.SigIdBoxText = $OperatorName
            $rec.SPUT         = $t.SPUT
            $rec.StartTime    = $t.StartTime
            $rec.EndTime      = $t.StopTime

            if ($confirmed) {
                $rec.ConfirmStatus = "$OperatorName - CONFIRMED COMPLETED"
                Write-Host "  -> CONFIRMED: $($rec.ConfirmStatus)" -ForegroundColor Green
            } else {
                $rec.ConfirmStatus = "$OperatorName - INCOMPLETE"
                Write-Host "  -> Recorded: $($rec.ConfirmStatus)" -ForegroundColor Red
            }
            Write-Host "======================================================================" -ForegroundColor Magenta
        } else {
            # Already achieved — just update times to most recent pass
            $rec.StartTime = $t.StartTime
            $rec.EndTime   = $t.StopTime
            $rec.SPUT      = $t.SPUT
            $updateCount++
        }
    }
}

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Processing Summary"
Write-Host "    New PLR Achievements:       $newCount"
Write-Host "    Subsequent Pass Updates:    $updateCount"
Write-Host "    Total Satellites Tracked:   $($plrRecords.Count)"
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

# ── 5. Write post_launch_requirements.xlsx ──────────────────────────
# Style indices (see xl/styles.xml below):
#   0 = default
#   1 = header row (bold white on dark blue)
#   2 = standard data cell (thin border, centered)
#   3 = RED box   (bold white text, red fill)
#   4 = GREEN box (bold white text, green fill)
#   5 = WHITE box (bold black text, white fill)

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
    <sheet name="PostLaunchRequirements" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
'@

# Fills: 0=none, 1=gray125, 2=DarkBlue, 3=Red, 4=Green, 5=White
$filesToZip["xl/styles.xml"] = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="3">
    <font><name val="Calibri"/><sz val="11"/></font>
    <font><b/><color rgb="FFFFFFFF"/><name val="Calibri"/><sz val="11"/></font>
    <font><b/><color rgb="FF000000"/><name val="Calibri"/><sz val="11"/></font>
  </fonts>
  <fills count="6">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFC00000"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF00B050"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFFFFFFF"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
      <left style="thin"><color rgb="FF999999"/></left>
      <right style="thin"><color rgb="FF999999"/></right>
      <top style="thin"><color rgb="FF999999"/></top>
      <bottom style="thin"><color rgb="FF999999"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="6">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center" wrapText="1"/>
    </xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <xf numFmtId="0" fontId="1" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center" wrapText="1"/>
    </xf>
    <xf numFmtId="0" fontId="1" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center" wrapText="1"/>
    </xf>
    <xf numFmtId="0" fontId="2" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
  </cellXfs>
</styleSheet>
'@

# ── Build sheet XML ─────────────────────────────────────────────────
$headers = @("SSC","Satellite Name","SPUT","SIG ID","Operator Confirm Next Requirement Completed","Start time","End time")
$cols    = @("A","B","C","D","E","F","G")

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
[void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
[void]$sb.AppendLine('  <cols>')
[void]$sb.AppendLine('    <col min="1" max="1" width="12" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="2" max="2" width="18" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="3" max="3" width="10" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="4" max="4" width="22" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="5" max="5" width="48" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="6" max="6" width="14" customWidth="1"/>')
[void]$sb.AppendLine('    <col min="7" max="7" width="14" customWidth="1"/>')
[void]$sb.AppendLine('  </cols>')
[void]$sb.AppendLine('  <sheetData>')

# Header
[void]$sb.AppendLine('    <row r="1" ht="28" customHeight="1">')
for ($c = 0; $c -lt $headers.Length; $c++) {
    $ref = "$($cols[$c])1"
    $val = [System.Security.SecurityElement]::Escape($headers[$c])
    [void]$sb.AppendLine("      <c r=`"$ref`" t=`"inlineStr`" s=`"1`"><is><t>$val</t></is></c>")
}
[void]$sb.AppendLine('    </row>')

# Data — sorted by SSC for readability
$rowIdx = 2
foreach ($ssc in ($plrRecords.Keys | Sort-Object)) {
    $rec = $plrRecords[$ssc]

    [void]$sb.AppendLine("    <row r=`"$rowIdx`" ht=`"22`" customHeight=`"1`">")

    # A: SSC (number)
    [void]$sb.AppendLine("      <c r=`"A$rowIdx`" s=`"2`"><v>$($rec.SSC)</v></c>")

    # B: Satellite Name (string)
    $vB = [System.Security.SecurityElement]::Escape($rec.SatName)
    [void]$sb.AppendLine("      <c r=`"B$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$vB</t></is></c>")

    # C: SPUT (number)
    [void]$sb.AppendLine("      <c r=`"C$rowIdx`" s=`"2`"><v>$($rec.SPUT)</v></c>")

    # D: SIG ID coloured box - RED (s=3) or GREEN (s=4) with NO text
    if ($rec.HasSigId) {
        [void]$sb.AppendLine("      <c r=`"D$rowIdx`" t=`"inlineStr`" s=`"4`"><is><t></t></is></c>")
    } else {
        [void]$sb.AppendLine("      <c r=`"D$rowIdx`" t=`"inlineStr`" s=`"3`"><is><t></t></is></c>")
    }

    # E: Operator Confirm Next Requirement Completed box - WHITE (s=5) / RED (s=3) / GREEN (s=4)
    if (-not $rec.HasSigId) {
        [void]$sb.AppendLine("      <c r=`"E$rowIdx`" t=`"inlineStr`" s=`"5`"><is><t></t></is></c>")
    } elseif ($rec.ConfirmStatus -match 'CONFIRMED COMPLETED') {
        $vE = [System.Security.SecurityElement]::Escape($rec.ConfirmStatus)
        [void]$sb.AppendLine("      <c r=`"E$rowIdx`" t=`"inlineStr`" s=`"4`"><is><t>$vE</t></is></c>")
    } else {
        $vE = [System.Security.SecurityElement]::Escape($rec.ConfirmStatus)
        [void]$sb.AppendLine("      <c r=`"E$rowIdx`" t=`"inlineStr`" s=`"3`"><is><t>$vE</t></is></c>")
    }

    # F: Start time (blank if no SIG ID)
    $vF = [System.Security.SecurityElement]::Escape($rec.StartTime)
    [void]$sb.AppendLine("      <c r=`"F$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$vF</t></is></c>")

    # G: End time (blank if no SIG ID)
    $vG = [System.Security.SecurityElement]::Escape($rec.EndTime)
    [void]$sb.AppendLine("      <c r=`"G$rowIdx`" t=`"inlineStr`" s=`"2`"><is><t>$vG</t></is></c>")

    [void]$sb.AppendLine('    </row>')
    $rowIdx++
}

[void]$sb.AppendLine('  </sheetData>')
[void]$sb.AppendLine('</worksheet>')
$filesToZip["xl/worksheets/sheet1.xml"] = $sb.ToString()

# ── Write xlsx ──────────────────────────────────────────────────────
$plrDir = Split-Path -Parent $PlrDocPath
if ($plrDir -and -not (Test-Path $plrDir)) {
    New-Item -ItemType Directory -Force -Path $plrDir | Out-Null
}

$fullPlrPath = Join-Path (Get-Location) $PlrDocPath
$targetSavePath = $fullPlrPath
try {
    if (Test-Path $fullPlrPath) { Remove-Item -Force $fullPlrPath }
    $fs = New-Object System.IO.FileStream($fullPlrPath, [System.IO.FileMode]::Create)
} catch {
    $targetSavePath = $fullPlrPath -replace '\.xlsx$', '_updated.xlsx'
    Write-Warning "File '$PlrDocPath' is open in Excel or locked. Saving to '$targetSavePath' instead."
    if (Test-Path $targetSavePath) { Remove-Item -Force $targetSavePath }
    $fs = New-Object System.IO.FileStream($targetSavePath, [System.IO.FileMode]::Create)
}

$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
$enc = New-Object System.Text.UTF8Encoding($false)

foreach ($key in $filesToZip.Keys) {
    $entry  = $zip.CreateEntry($key, [System.IO.Compression.CompressionLevel]::Optimal)
    $es     = $entry.Open()
    $writer = New-Object System.IO.StreamWriter($es, $enc)
    $writer.Write($filesToZip[$key])
    $writer.Dispose(); $es.Dispose()
}
$zip.Dispose(); $fs.Dispose()

Write-Host ""
Write-Host "[DONE] PLR document saved: $targetSavePath" -ForegroundColor Green
Write-Host ""
