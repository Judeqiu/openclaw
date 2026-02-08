#!/usr/bin/env node
/**
 * Extract structured data from web pages using OpenClaw browser
 * Usage: extract-data.js --url <url> --selector <selector> [--fields <fields>] [--output <file>]
 */

import { execSync } from 'child_process';
import fs from 'fs';

// Parse arguments
const args = process.argv.slice(2);
const getArg = (flag) => {
  const index = args.indexOf(flag);
  return index !== -1 ? args[index + 1] : null;
};

const url = getArg('--url');
const selector = getArg('--selector') || 'body';
const fields = getArg('--fields')?.split(',') || ['text'];
const output = getArg('--output');
const waitFor = getArg('--wait-for');
const timeout = parseInt(getArg('--timeout') || '30000');

if (!url) {
  console.error('Usage: extract-data.js --url <url> [--selector <selector>] [--fields <fields>] [--output <file>] [--wait-for <selector>]');
  process.exit(1);
}

function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', timeout });
  } catch (e) {
    console.error(`Command failed: ${cmd}`);
    console.error(e.stderr || e.message);
    process.exit(1);
  }
}

console.log(`🔍 Extracting data from: ${url}`);

// Start browser if not running
const status = run('openclaw browser status --json');
const statusObj = JSON.parse(status);
if (!statusObj.running) {
  console.log('🚀 Starting browser...');
  run('openclaw browser start');
}

// Navigate to page
console.log(`📄 Navigating to ${url}...`);
run(`openclaw browser navigate "${url}"`);

// Wait for specific element if requested
if (waitFor) {
  console.log(`⏳ Waiting for: ${waitFor}`);
  run(`openclaw browser wait "${waitFor}" --timeout-ms ${timeout}`);
} else {
  // Wait for network idle
  run('openclaw browser wait --load networkidle');
}

// Extract data
console.log(`📊 Extracting data with selector: ${selector}`);
const extractionFn = `
  Array.from(document.querySelectorAll('${selector}')).map((el, i) => {
    const result = { index: i };
    ${fields.map(f => {
      if (f === 'text') return `result.text = el.textContent?.trim();`;
      if (f === 'html') return `result.html = el.innerHTML;`;
      if (f === 'href') return `result.href = el.href || el.querySelector('a')?.href;`;
      if (f === 'src') return `result.src = el.src || el.querySelector('img')?.src;`;
      return `result['${f}'] = el.getAttribute('${f}') || el.querySelector('[${f}]')?.getAttribute('${f}');`;
    }).join('\n    ')}
    return result;
  })
`;

const result = run(`openclaw browser evaluate --fn '${extractionFn}' --json`);
const data = JSON.parse(result);

console.log(`✅ Extracted ${data.result?.length || 0} items`);

// Output results
const outputData = {
  url,
  selector,
  fields,
  extractedAt: new Date().toISOString(),
  data: data.result || []
};

const jsonOutput = JSON.stringify(outputData, null, 2);

if (output) {
  fs.writeFileSync(output, jsonOutput);
  console.log(`💾 Saved to: ${output}`);
} else {
  console.log('\n📋 Results:');
  console.log(jsonOutput);
}
