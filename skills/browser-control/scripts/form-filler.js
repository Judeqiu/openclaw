#!/usr/bin/env node
/**
 * Automated form filling using OpenClaw browser
 * Usage: form-filler.js --url <url> --form-file <json-file> [--submit]
 */

import { execSync } from 'child_process';
import fs from 'fs';

const args = process.argv.slice(2);
const getArg = (flag) => {
  const index = args.indexOf(flag);
  return index !== -1 ? args[index + 1] : null;
};

const url = getArg('--url');
const formFile = getArg('--form-file');
const submit = args.includes('--submit');
const profile = getArg('--profile') || 'openclaw';

if (!url || !formFile) {
  console.error('Usage: form-filler.js --url <url> --form-file <json-file> [--submit] [--profile <profile>]');
  console.error('\nForm file format:');
  console.error(JSON.stringify({
    fields: [
      { ref: 'e12', type: 'text', value: 'John Doe' },
      { ref: 'e13', type: 'email', value: 'john@example.com' },
      { ref: 'e14', type: 'select', value: 'Option 1' }
    ]
  }, null, 2));
  process.exit(1);
}

function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8' });
  } catch (e) {
    console.error(`Command failed: ${cmd}`);
    console.error(e.stderr || e.message);
    process.exit(1);
  }
}

// Load form data
const formData = JSON.parse(fs.readFileSync(formFile, 'utf8'));

console.log(`📝 Form Filler - ${url}`);
console.log(`   Profile: ${profile}`);
console.log(`   Fields: ${formData.fields?.length || 0}`);

// Ensure browser is running
const status = run('openclaw browser status --json');
const statusObj = JSON.parse(status);
if (!statusObj.running) {
  console.log('🚀 Starting browser...');
  run(`openclaw browser start --browser-profile ${profile}`);
}

// Navigate to form
console.log(`📄 Opening form...`);
run(`openclaw browser --browser-profile ${profile} open "${url}"`);
run('openclaw browser wait --load networkidle');

// Fill each field
console.log('⌨️  Filling fields...');
for (const field of formData.fields || []) {
  const { ref, type, value } = field;
  
  switch (type) {
    case 'text':
    case 'email':
    case 'password':
    case 'tel':
    case 'number':
      console.log(`   [${ref}] ${type}: ${value}`);
      run(`openclaw browser type ${ref} "${value}"`);
      break;
      
    case 'select':
      console.log(`   [${ref}] select: ${value}`);
      run(`openclaw browser select ${ref} "${value}"`);
      break;
      
    case 'checkbox':
      console.log(`   [${ref}] checkbox: ${value ? 'checked' : 'unchecked'}`);
      if (value) {
        run(`openclaw browser click ${ref}`);
      }
      break;
      
    case 'radio':
      console.log(`   [${ref}] radio: ${value}`);
      run(`openclaw browser click ${ref}`);
      break;
      
    default:
      console.log(`   [${ref}] unknown type: ${type}`);
  }
}

// Submit if requested
if (submit) {
  console.log('📤 Submitting form...');
  const submitRef = formData.submitRef || 'e' + (Math.max(...formData.fields.map(f => parseInt(f.ref?.replace('e', '') || 0))) + 1);
  run(`openclaw browser click ${submitRef}`);
  
  // Wait for navigation
  run('openclaw browser wait --load networkidle');
  console.log('✅ Form submitted successfully');
} else {
  console.log('⏸️  Form filled (not submitted)');
}

// Screenshot for verification
const screenshotPath = `/tmp/form-filled-${Date.now()}.png`;
run(`openclaw browser screenshot --full-page --output ${screenshotPath}`);
console.log(`📸 Screenshot saved: ${screenshotPath}`);
