#!/usr/bin/env node
/**
 * Post-Launch Requirements (PLR) Task Log Verification Program
 * Designed to run directly inside the Visual Studio Code integrated terminal.
 *
 * Usage:
 *   node tools/check_plr_tasks.js
 *   node tools/check_plr_tasks.js --task-log output/2026-11-06.xlsx --operator "Sgt_Smith"
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const zlib = require('zlib');

// ANSI Terminal Colors for VS Code Terminal
const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  magenta: '\x1b[35m',
  red: '\x1b[31m',
  gray: '\x1b[90m',
  white: '\x1b[37m',
  bgBlue: '\x1b[44m'
};

// ── Minimal In-Memory ZIP Reader ─────────────────────────────────────
function readZip(buffer) {
  const files = {};
  const eocdOffset = buffer.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (eocdOffset === -1) throw new Error('Invalid XLSX: EOCD record not found.');
  const cdOffset = buffer.readUInt32LE(eocdOffset + 16);
  const totalEntries = buffer.readUInt16LE(eocdOffset + 10);

  let pos = cdOffset;
  for (let i = 0; i < totalEntries; i++) {
    if (buffer.readUInt32LE(pos) !== 0x02014b50) break;
    const method = buffer.readUInt16LE(pos + 10);
    const compSize = buffer.readUInt32LE(pos + 20);
    const fnLen = buffer.readUInt16LE(pos + 28);
    const extraLen = buffer.readUInt16LE(pos + 30);
    const commentLen = buffer.readUInt16LE(pos + 32);
    const localHeaderOffset = buffer.readUInt32LE(pos + 42);
    const filename = buffer.toString('utf8', pos + 46, pos + 46 + fnLen);

    const localFnLen = buffer.readUInt16LE(localHeaderOffset + 26);
    const localExtraLen = buffer.readUInt16LE(localHeaderOffset + 28);
    const dataOffset = localHeaderOffset + 30 + localFnLen + localExtraLen;
    const compData = buffer.subarray(dataOffset, dataOffset + compSize);

    let data;
    if (method === 0) {
      data = compData;
    } else if (method === 8) {
      data = zlib.inflateRawSync(compData);
    } else {
      throw new Error(`Unsupported compression method: ${method}`);
    }
    files[filename] = data.toString('utf8');
    pos += 46 + fnLen + extraLen + commentLen;
  }
  return files;
}

// ── Minimal In-Memory ZIP Writer ─────────────────────────────────────
function writeZip(files) {
  const localChunks = [];
  const cdChunks = [];
  let offset = 0;

  for (const [name, content] of Object.entries(files)) {
    const nameBuf = Buffer.from(name, 'utf8');
    const rawBuf = Buffer.isBuffer(content) ? content : Buffer.from(content, 'utf8');
    const crc = zlib.crc32(rawBuf);
    const compBuf = zlib.deflateRawSync(rawBuf);

    // Local file header (30 bytes)
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);
    lh.writeUInt16LE(20, 4);
    lh.writeUInt16LE(0, 6);
    lh.writeUInt16LE(8, 8);
    lh.writeUInt16LE(0, 10);
    lh.writeUInt16LE(0, 12);
    lh.writeUInt32LE(crc, 14);
    lh.writeUInt32LE(compBuf.length, 18);
    lh.writeUInt32LE(rawBuf.length, 22);
    lh.writeUInt16LE(nameBuf.length, 26);
    lh.writeUInt16LE(0, 28);

    localChunks.push(lh, nameBuf, compBuf);

    // Central directory header (46 bytes)
    const cdh = Buffer.alloc(46);
    cdh.writeUInt32LE(0x02014b50, 0);
    cdh.writeUInt16LE(20, 4);
    cdh.writeUInt16LE(20, 6);
    cdh.writeUInt16LE(0, 8);
    cdh.writeUInt16LE(8, 10);
    cdh.writeUInt16LE(0, 12);
    cdh.writeUInt16LE(0, 14);
    cdh.writeUInt32LE(crc, 16);
    cdh.writeUInt32LE(compBuf.length, 20);
    cdh.writeUInt32LE(rawBuf.length, 24);
    cdh.writeUInt16LE(nameBuf.length, 28);
    cdh.writeUInt16LE(0, 30);
    cdh.writeUInt16LE(0, 32);
    cdh.writeUInt16LE(0, 34);
    cdh.writeUInt16LE(0, 36);
    cdh.writeUInt32LE(0, 38);
    cdh.writeUInt32LE(offset, 42);

    cdChunks.push(cdh, nameBuf);
    offset += lh.length + nameBuf.length + compBuf.length;
  }

  const cdStart = offset;
  let cdSize = 0;
  for (const c of cdChunks) cdSize += c.length;

  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  const entryCount = Object.keys(files).length;
  eocd.writeUInt16LE(entryCount, 8);
  eocd.writeUInt16LE(entryCount, 10);
  eocd.writeUInt32LE(cdSize, 12);
  eocd.writeUInt32LE(cdStart, 16);
  eocd.writeUInt16LE(0, 20);

  return Buffer.concat([...localChunks, ...cdChunks, eocd]);
}

// ── Lightweight XML Parser for Excel Rows ───────────────────────────
function parseSheetRows(xmlStr) {
  const rowMatches = xmlStr.match(/<row[\s\S]*?<\/row>/g) || [];
  const parsedRows = [];

  for (const rowXml of rowMatches) {
    const rMatch = rowXml.match(/<row[^>]*r="(\d+)"/);
    const rowNum = rMatch ? parseInt(rMatch[1], 10) : parsedRows.length + 1;
    const cellMatches = rowXml.match(/<c\b[^>]*?(?:\/>|>[\s\S]*?<\/c>)/g) || [];
    const cells = [];

    for (const cellXml of cellMatches) {
      const refMatch = cellXml.match(/r="([A-Z]+\d+)"/);
      const styleMatch = cellXml.match(/s="(\d+)"/);
      const isMatch = cellXml.match(/<is><t[^>]*>([\s\S]*?)<\/t><\/is>/);
      const vMatch = cellXml.match(/<v>([\s\S]*?)<\/v>/);

      const ref = refMatch ? refMatch[1] : '';
      const style = styleMatch ? styleMatch[1] : '0';
      const value = isMatch ? isMatch[1] : (vMatch ? vMatch[1] : '');

      cells.push({ ref, style, value: unescapeXml(value) });
    }
    parsedRows.push({ rowNum, cells });
  }
  return parsedRows;
}

function escapeXml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function unescapeXml(str) {
  if (!str) return '';
  return str
    .replace(/&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&gt;/g, '>')
    .replace(/&lt;/g, '<')
    .replace(/&amp;/g, '&');
}

// ── Command-Line Prompt Helper ───────────────────────────────────────
function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise(resolve => {
    rl.question(query, ans => {
      rl.close();
      resolve(ans.trim());
    });
  });
}

// ── Parse CLI Arguments ──────────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--task-log' && args[i + 1]) options.taskLog = args[++i];
    else if (args[i] === '--plr-doc' && args[i + 1]) options.plrDoc = args[++i];
    else if (args[i] === '--operator' && args[i + 1]) options.operator = args[++i];
    else if (args[i] === '--non-interactive') options.nonInteractive = true;
    else if (args[i] === '--auto-confirm') options.autoConfirm = args[++i] || 'y';
  }
  return options;
}

// ── Select Task Log from Output Folder ──────────────────────────────
async function selectTaskLog(outputFolder = 'output', preferredPath = null) {
  if (preferredPath) {
    if (fs.existsSync(preferredPath)) return preferredPath;
    console.log(`${c.yellow}[WARN] Specified path '${preferredPath}' not found. Selecting from available logs...${c.reset}\n`);
  }

  let availableFiles = [];
  if (fs.existsSync(outputFolder)) {
    availableFiles = fs.readdirSync(outputFolder)
      .filter(file => file.endsWith('.xlsx') && !file.toLowerCase().includes('post_launch_requirements') && !file.startsWith('~$'))
      .sort((a, b) => b.localeCompare(a)); // Sort latest date first
  }

  if (availableFiles.length === 0) {
    console.log(`${c.yellow}[INFO] No task log files found in '${outputFolder}/'.${c.reset}`);
    let customPath = await askQuestion(`${c.white}Enter path to Satellite Task Log Excel file: ${c.reset}`);
    while (!fs.existsSync(customPath)) {
      console.log(`${c.red}File not found: ${customPath}${c.reset}`);
      customPath = await askQuestion(`${c.white}Please enter a valid file path: ${c.reset}`);
    }
    return customPath;
  }

  console.log(`${c.cyan}${c.bold}Available Satellite Task Logs in '${outputFolder}/':${c.reset}`);
  availableFiles.forEach((file, idx) => {
    const fullPath = path.join(outputFolder, file);
    const stats = fs.statSync(fullPath);
    const mtime = stats.mtime.toISOString().replace('T', ' ').substring(0, 19);
    const tag = idx === 0 ? ` ${c.green}${c.bold}(Latest)${c.reset}` : '';
    console.log(`  ${c.cyan}[${idx + 1}]${c.reset} ${c.bold}${file}${c.reset}${tag}  ${c.gray}(Modified: ${mtime})${c.reset}`);
  });
  console.log(`  ${c.cyan}[C]${c.reset} ${c.gray}Enter a custom file path...${c.reset}\n`);

  while (true) {
    const ans = await askQuestion(`${c.white}Select task log number [1-${availableFiles.length}, default: 1]: ${c.reset}`);
    const choice = ans.trim();

    if (!choice || choice === '1') {
      const selected = path.join(outputFolder, availableFiles[0]);
      console.log(`${c.green}Selected: ${selected}${c.reset}\n`);
      return selected;
    }

    if (choice.toLowerCase() === 'c') {
      let customPath = await askQuestion(`${c.white}Enter custom path to task log: ${c.reset}`);
      while (!fs.existsSync(customPath)) {
        console.log(`${c.red}File not found: ${customPath}${c.reset}`);
        customPath = await askQuestion(`${c.white}Please enter a valid file path: ${c.reset}`);
      }
      return customPath;
    }

    const num = parseInt(choice, 10);
    if (!isNaN(num) && num >= 1 && num <= availableFiles.length) {
      const selected = path.join(outputFolder, availableFiles[num - 1]);
      console.log(`${c.green}Selected: ${selected}${c.reset}\n`);
      return selected;
    }

    if (availableFiles.includes(choice)) {
      const selected = path.join(outputFolder, choice);
      console.log(`${c.green}Selected: ${selected}${c.reset}\n`);
      return selected;
    } else if (fs.existsSync(choice)) {
      console.log(`${c.green}Selected: ${choice}${c.reset}\n`);
      return choice;
    }

    console.log(`${c.red}Invalid selection. Please enter a number between 1 and ${availableFiles.length}, or 'C' for custom.${c.reset}`);
  }
}

// ── Main Routine ─────────────────────────────────────────────────────
async function main() {
  console.clear();
  console.log(`${c.cyan}${c.bold}============================================================${c.reset}`);
  console.log(`${c.cyan}${c.bold}   Post-Launch Requirements (PLR) Verification Program      ${c.reset}`);
  console.log(`${c.gray}   Visual Studio Code Integrated Terminal Environment       ${c.reset}`);
  console.log(`${c.cyan}${c.bold}============================================================${c.reset}\n`);

  const opts = parseArgs();

  // 1. Task Log selection from generator output folder
  const taskLogPath = await selectTaskLog('output', opts.taskLog);

  // 2. PLR Document path
  let plrDocPath = opts.plrDoc || 'output/post_launch_requirements.xlsx';

  // 3. Operator Name
  let operatorName = opts.operator;
  if (!operatorName) {
    if (opts.nonInteractive) {
      operatorName = 'OPERATOR_01';
    } else {
      const prompt = `${c.white}Enter Operator Name/Callsign ${c.gray}[default: OPERATOR_01]${c.white}: ${c.reset}`;
      const ans = await askQuestion(prompt);
      operatorName = ans || 'OPERATOR_01';
    }
  }

  console.log(`\n${c.gray}Active Configuration:${c.reset}`);
  console.log(`  ${c.bold}Task Log:${c.reset}    ${taskLogPath}`);
  console.log(`  ${c.bold}PLR File:${c.reset}    ${plrDocPath}`);
  console.log(`  ${c.bold}Operator:${c.reset}    ${c.green}${operatorName}${c.reset}\n`);

  // 4. Load or Initialize PLR in-memory records
  const plrRecords = new Map(); // key: SSC (number)

  if (fs.existsSync(plrDocPath)) {
    console.log(`${c.yellow}[INFO] Loading existing PLR tracking document: ${plrDocPath}...${c.reset}`);
    try {
      const zipData = readZip(fs.readFileSync(plrDocPath));
      const sheetXml = zipData['xl/worksheets/sheet1.xml'];
      const rows = parseSheetRows(sheetXml);

      for (let i = 1; i < rows.length; i++) {
        const cells = rows[i].cells;
        if (!cells || cells.length === 0) continue;

        const cellMap = {};
        for (const cell of cells) {
          const col = cell.ref ? cell.ref.replace(/\d+/, '') : '';
          if (col) cellMap[col] = cell;
        }

        const ssc = parseInt(cellMap['A']?.value, 10);
        if (isNaN(ssc)) continue;

        const satName = cellMap['B']?.value || '';
        const sput = parseInt(cellMap['C']?.value, 10) || 0;
        const sigStyle = cellMap['D']?.style || '0';
        const confBox = cellMap['E']?.value || '';
        const startVal = cellMap['F']?.value || '';
        const stopVal = cellMap['G']?.value || '';

        const hasSigId = sigStyle === '4' || startVal.trim().length > 0 || confBox.trim().length > 0;

        plrRecords.set(ssc, {
          ssc,
          satName,
          sput,
          hasSigId,
          confirmStatus: confBox,
          startTime: startVal,
          endTime: stopVal
        });
      }
      console.log(`${c.green}  Loaded ${plrRecords.size} existing satellite records from PLR document.${c.reset}`);
    } catch (err) {
      console.log(`${c.yellow}  Could not parse existing PLR document (${err.message}). Starting fresh.${c.reset}`);
    }
  } else {
    console.log(`${c.cyan}[INFO] PLR document not found. A new one will be created at: ${plrDocPath}${c.reset}`);
  }

  // 5. Read Task Log
  console.log(`${c.yellow}[INFO] Reading task log: ${taskLogPath}...${c.reset}`);
  const taskZip = readZip(fs.readFileSync(taskLogPath));
  const taskSheetXml = taskZip['xl/worksheets/sheet1.xml'];
  const taskRows = parseSheetRows(taskSheetXml);
  const tasks = [];

  for (let i = 1; i < taskRows.length; i++) {
    const cList = taskRows[i].cells;
    if (!cList || cList.length < 7) continue;
    tasks.push({
      taskNum: parseInt(cList[0].value, 10),
      satName: cList[1].value,
      ssc: parseInt(cList[2].value, 10),
      sput: parseInt(cList[3].value, 10),
      signalId: cList[4].value,
      startTime: cList[5].value,
      stopTime: cList[6].value
    });
  }

  console.log(`${c.green}  Found ${tasks.length} tasks in log.${c.reset}\n`);

  // 6. Compare tasks against PLR records
  let newAchievementsCount = 0;
  let updatedPassesCount = 0;

  for (const t of tasks) {
    const ssc = t.ssc;

    if (!plrRecords.has(ssc)) {
      plrRecords.set(ssc, {
        ssc,
        satName: t.satName,
        sput: t.sput,
        hasSigId: false,
        confirmStatus: '',
        startTime: '',
        endTime: ''
      });
    }

    const rec = plrRecords.get(ssc);
    if (!rec.satName) rec.satName = t.satName;

    const hasSig = t.signalId && t.signalId !== 'neg' && t.signalId !== 'NO SIGNAL';

    if (hasSig) {
      if (!rec.hasSigId) {
        // FIRST SIG ID FOR THIS SATELLITE
        newAchievementsCount++;
        console.log(`\n${c.magenta}======================================================================${c.reset}`);
        console.log(`${c.yellow}${c.bold} [ALERT] NEW SIGNAL ID DETECTED -- PLR REQUIREMENT MET!${c.reset}`);
        console.log(`${c.magenta}======================================================================${c.reset}`);
        console.log(`  ${c.bold}Task Number:${c.reset}    #${t.taskNum}`);
        console.log(`  ${c.bold}Satellite:${c.reset}      ${t.satName}`);
        console.log(`  ${c.bold}SSC:${c.reset}            ${t.ssc}`);
        console.log(`  ${c.bold}SPUT:${c.reset}           ${t.sput}`);
        console.log(`  ${c.bold}Signal ID:${c.reset}      ${c.green}${c.bold}${t.signalId}${c.reset}`);
        console.log(`  ${c.bold}Start Time:${c.reset}     ${t.startTime}`);
        console.log(`  ${c.bold}Stop Time:${c.reset}      ${t.stopTime}`);
        console.log(`${c.magenta}----------------------------------------------------------------------${c.reset}`);

        let confirmed = false;
        if (opts.nonInteractive) {
          confirmed = (opts.autoConfirm || 'y').toLowerCase().startsWith('y');
          console.log(`  ${c.gray}[AUTO-CONFIRM] Operator confirmation defaulted to: ${opts.autoConfirm || 'y'}${c.reset}`);
        } else {
          const ans = await askQuestion(`  ${c.white}${c.bold}Have subsequent mission requirements been completed for this satellite? (y/n): ${c.reset}`);
          confirmed = ans.toLowerCase().startsWith('y');
        }

        rec.hasSigId = true;
        rec.sput = t.sput;
        rec.startTime = t.startTime;
        rec.endTime = t.stopTime;

        if (confirmed) {
          rec.confirmStatus = `${operatorName} - CONFIRMED COMPLETED`;
          console.log(`  ${c.green}${c.bold}-> Status: Requirement confirmed: ${rec.confirmStatus}${c.reset}`);
        } else {
          rec.confirmStatus = `${operatorName} - INCOMPLETE`;
          console.log(`  ${c.red}${c.bold}-> Status: Requirement recorded: ${rec.confirmStatus}${c.reset}`);
        }
        console.log(`${c.magenta}======================================================================${c.reset}`);
      } else {
        // Satellite already achieved: update start/stop times to most recent pass
        rec.startTime = t.startTime;
        rec.endTime = t.stopTime;
        rec.sput = t.sput;
        updatedPassesCount++;
      }
    }
  }

  console.log(`\n${c.cyan}------------------------------------------------------------${c.reset}`);
  console.log(`${c.bold}Processing Summary:${c.reset}`);
  console.log(`  ${c.yellow}Newly Achieved PLR Satellites:${c.reset} ${newAchievementsCount}`);
  console.log(`  ${c.cyan}Subsequent Passes Updated:${c.reset}     ${updatedPassesCount}`);
  console.log(`  ${c.green}Total Satellites Tracked:${c.reset}      ${plrRecords.size}`);
  console.log(`${c.cyan}------------------------------------------------------------${c.reset}\n`);

  // 7. Build Updated post_launch_requirements.xlsx
  const outputDir = path.dirname(plrDocPath);
  if (outputDir && !fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const filesToZip = {};

  filesToZip['[Content_Types].xml'] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>`;

  filesToZip['_rels/.rels'] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`;

  filesToZip['xl/_rels/workbook.xml.rels'] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>`;

  filesToZip['xl/workbook.xml'] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="PostLaunchRequirements" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>`;

  // Fills: 0=none, 1=gray125, 2=DarkBlue, 3=Red, 4=Green, 5=White
  filesToZip['xl/styles.xml'] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
</styleSheet>`;

  const headers = [
    'SSC',
    'Satellite Name',
    'SPUT',
    'SIG ID',
    'Operator Confirm Next Requirement Completed',
    'Start time',
    'End time'
  ];
  const cols = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  let sheetXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <cols>
    <col min="1" max="1" width="12" customWidth="1"/>
    <col min="2" max="2" width="18" customWidth="1"/>
    <col min="3" max="3" width="10" customWidth="1"/>
    <col min="4" max="4" width="22" customWidth="1"/>
    <col min="5" max="5" width="48" customWidth="1"/>
    <col min="6" max="6" width="14" customWidth="1"/>
    <col min="7" max="7" width="14" customWidth="1"/>
  </cols>
  <sheetData>
    <row r="1" ht="28" customHeight="1">
`;

  headers.forEach((h, idx) => {
    sheetXml += `      <c r="${cols[idx]}1" t="inlineStr" s="1"><is><t>${escapeXml(h)}</t></is></c>\n`;
  });
  sheetXml += '    </row>\n';

  // Sort by SSC
  const sortedSscs = Array.from(plrRecords.keys()).sort((a, b) => a - b);
  let rowIdx = 2;

  for (const ssc of sortedSscs) {
    const rec = plrRecords.get(ssc);
    sheetXml += `    <row r="${rowIdx}" ht="22" customHeight="1">\n`;

    // A: SSC
    sheetXml += `      <c r="A${rowIdx}" s="2"><v>${rec.ssc}</v></c>\n`;
    // B: Satellite Name
    sheetXml += `      <c r="B${rowIdx}" t="inlineStr" s="2"><is><t>${escapeXml(rec.satName)}</t></is></c>\n`;
    // C: SPUT
    sheetXml += `      <c r="C${rowIdx}" s="2"><v>${rec.sput}</v></c>\n`;

    // D: SIG ID colored box - Green (s=4) or Red (s=3) with NO text
    if (rec.hasSigId) {
      sheetXml += `      <c r="D${rowIdx}" t="inlineStr" s="4"><is><t></t></is></c>\n`;
    } else {
      sheetXml += `      <c r="D${rowIdx}" t="inlineStr" s="3"><is><t></t></is></c>\n`;
    }

    // E: Operator Confirm Next Requirement Completed box
    // White (s=5) if no SIG ID; Green (s=4) for CONFIRMED COMPLETED; Red (s=3) for INCOMPLETE
    if (!rec.hasSigId) {
      sheetXml += `      <c r="E${rowIdx}" t="inlineStr" s="5"><is><t></t></is></c>\n`;
    } else if (rec.confirmStatus && rec.confirmStatus.includes('CONFIRMED COMPLETED')) {
      sheetXml += `      <c r="E${rowIdx}" t="inlineStr" s="4"><is><t>${escapeXml(rec.confirmStatus)}</t></is></c>\n`;
    } else {
      sheetXml += `      <c r="E${rowIdx}" t="inlineStr" s="3"><is><t>${escapeXml(rec.confirmStatus)}</t></is></c>\n`;
    }

    // F: Start time
    sheetXml += `      <c r="F${rowIdx}" t="inlineStr" s="2"><is><t>${escapeXml(rec.startTime)}</t></is></c>\n`;
    // G: End time
    sheetXml += `      <c r="G${rowIdx}" t="inlineStr" s="2"><is><t>${escapeXml(rec.endTime)}</t></is></c>\n`;

    sheetXml += '    </row>\n';
    rowIdx++;
  }

  sheetXml += '  </sheetData>\n</worksheet>';
  filesToZip['xl/worksheets/sheet1.xml'] = sheetXml;

  const zipBuffer = writeZip(filesToZip);
  try {
    fs.writeFileSync(plrDocPath, zipBuffer);
    console.log(`${c.green}${c.bold}[DONE] Successfully updated PLR document:${c.reset} ${plrDocPath}\n`);
  } catch (err) {
    if (err.code === 'EBUSY') {
      const fallbackPath = plrDocPath.replace(/\.xlsx$/i, '_updated.xlsx');
      fs.writeFileSync(fallbackPath, zipBuffer);
      console.log(`\n${c.yellow}${c.bold}[WARN] '${plrDocPath}' is currently open in Microsoft Excel.${c.reset}`);
      console.log(`${c.yellow}Saved updated file to:${c.reset} ${c.bold}${fallbackPath}${c.reset}`);
      console.log(`${c.gray}To overwrite the original, please close Excel and re-run, or save this file over it.${c.reset}\n`);
    } else {
      throw err;
    }
  }
}

main().catch(err => {
  console.error(`${c.red}[ERROR] ${err.message}${c.reset}`);
  process.exit(1);
});
