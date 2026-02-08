#!/usr/bin/env node
/**
 * Monitor a webpage for changes
 * Usage: monitor-page.js --url <url> --selector <selector> [--interval <seconds>] [--command <cmd>]
 */

import { execSync, spawn } from 'child_process';
import crypto from 'crypto';
import fs from 'fs';

const args = process.argv.slice(2);
const getArg = (flag) => {
  const index = args.indexOf(flag);
  return index !== -1 ? args[index + 1] : null;
};

const url = getArg('--url');
const selector = getArg('--selector') || 'body';
const interval = parseInt(getArg('--interval') || '60');
const command = getArg('--command');
const outputDir = getArg('--output-dir') || '/tmp/browser-monitor';

if (!url) {
  console.error('Usage: monitor-page.js --url <url> [--selector <selector>] [--interval <seconds>] [--command <cmd>] [--output-dir <dir>]');
  process.exit(1);
}

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', timeout: 30000 });
  } catch (e) {
    return null;
  }
}

function hash(str) {
  return crypto.createHash('md5').update(str).digest('hex');
}

console.log(`👁️  Page Monitor Started`);
console.log(`   URL: ${url}`);
console.log(`   Selector: ${selector}`);
console.log(`   Interval: ${interval}s`);
console.log(`   Output: ${outputDir}`);
console.log(`   Press Ctrl+C to stop\n`);

let lastHash = null;
let checkCount = 0;

function check() {
  checkCount++;
  const timestamp = new Date().toISOString();
  
  try {
    // Navigate and extract
    run(`openclaw browser navigate "${url}"`);
    run('openclaw browser wait --load networkidle');
    
    const result = run(`openclaw browser evaluate --fn '
      const el = document.querySelector("${selector}");
      el ? el.textContent.trim() : "NOT_FOUND";
    ' --json`);
    
    if (!result) {
      console.log(`[${timestamp}] ⚠️  Failed to extract content`);
      return;
    }
    
    const data = JSON.parse(result);
    const content = data.result;
    const currentHash = hash(content);
    
    // Save snapshot
    const snapshotFile = `${outputDir}/snapshot-${Date.now()}.txt`;
    fs.writeFileSync(snapshotFile, content);
    
    // Check for changes
    if (lastHash === null) {
      console.log(`[${timestamp}] 📸 Initial snapshot captured (${content.length} chars)`);
      lastHash = currentHash;
    } else if (currentHash !== lastHash) {
      console.log(`[${timestamp}] 🔔 CHANGE DETECTED!`);
      console.log(`   Content length: ${content.length} chars`);
      console.log(`   Snapshot: ${snapshotFile}`);
      
      // Run command if specified
      if (command) {
        console.log(`   Running: ${command}`);
        spawn(command, { shell: true, stdio: 'inherit' });
      }
      
      // Take screenshot
      const screenshotPath = `${outputDir}/screenshot-${Date.now()}.png`;
      run(`openclaw browser screenshot --full-page --output ${screenshotPath}`);
      
      lastHash = currentHash;
    } else {
      console.log(`[${timestamp}] ✓ No changes (${content.length} chars)`);
    }
    
  } catch (e) {
    console.error(`[${timestamp}] ❌ Error: ${e.message}`);
  }
}

// Initial check
check();

// Schedule subsequent checks
const timer = setInterval(check, interval * 1000);

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n🛑 Monitor stopped');
  clearInterval(timer);
  process.exit(0);
});
