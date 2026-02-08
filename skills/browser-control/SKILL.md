---
name: browser-control
description: Advanced browser automation for web retrieval, manipulation, and data extraction. Use when Codex needs to control a browser to navigate websites, extract data, fill forms, take screenshots, perform actions (click/type/scroll), or automate web workflows. Includes scripts for common patterns like scraping, form filling, monitoring, and batch operations.
---

# Browser Control Skill

Advanced browser automation for retrieving and manipulating web content through OpenClaw's managed browser.

## Quick Start

```bash
# Start browser and open page
openclaw browser start
openclaw browser open https://example.com

# Get page snapshot
openclaw browser snapshot --interactive

# Perform actions (use refs from snapshot)
openclaw browser click 12
openclaw browser type 23 "search query" --submit

# Capture screenshot
openclaw browser screenshot --full-page
```

## Common Workflows

### 1. Web Scraping & Data Extraction

**Basic pattern:**
1. Navigate to target page
2. Wait for content to load
3. Capture structured snapshot
4. Extract data using JavaScript evaluation

```bash
# Navigate and wait for load
openclaw browser navigate https://news.ycombinator.com
openclaw browser wait --load networkidle

# Get interactive snapshot
openclaw browser snapshot --interactive --json

# Extract specific data via JavaScript
openclaw browser evaluate --fn '
  Array.from(document.querySelectorAll(".titleline > a"))
    .slice(0, 5)
    .map(a => ({title: a.textContent, url: a.href}))
'
```

**Use skill script for complex extraction:**
```bash
./skills/browser-control/scripts/extract-data.js \
  --url "https://example.com/products" \
  --selector ".product-item" \
  --fields "name,price,image"
```

### 2. Form Filling & Submission

```bash
# Navigate to form
openclaw browser open https://example.com/form

# Get snapshot to find field refs
openclaw browser snapshot --interactive

# Fill form fields
openclaw browser type e12 "John Doe"
openclaw browser type e13 "john@example.com"
openclaw browser select e14 "United States"
openclaw browser click e15 --submit

# Or use batch fill
openclaw browser fill --fields '[
  {"ref":"e12","type":"text","value":"John Doe"},
  {"ref":"e13","type":"email","value":"john@example.com"}
]'
```

### 3. Screenshot & PDF Capture

```bash
# Full page screenshot
openclaw browser screenshot --full-page --output /tmp/page.png

# Specific element
openclaw browser screenshot --ref e23 --output /tmp/element.png

# PDF export
openclaw browser pdf --output /tmp/page.pdf

# With labels for documentation
openclaw browser snapshot --interactive --labels
openclaw browser screenshot --labels --output /tmp/labeled.png
```

### 4. Session Persistence

```bash
# Save cookies for later
openclaw browser cookies --json > /tmp/cookies.json

# Restore session
openclaw browser cookies set --json "$(cat /tmp/cookies.json)"

# Save storage (localStorage/sessionStorage)
openclaw browser storage local get > /tmp/localstorage.json
```

### 5. Batch Operations

Use the batch script for multi-page operations:

```bash
./skills/browser-control/scripts/batch-scrape.js \
  --urls "https://site.com/page1,https://site.com/page2" \
  --action "extract-links" \
  --output /tmp/results.json
```

## Advanced Techniques

### Waiting Strategies

```bash
# Wait for element to appear
openclaw browser wait "#dynamic-content" --timeout-ms 10000

# Wait for URL pattern
openclaw browser wait --url "**/success" --timeout-ms 15000

# Wait for JavaScript condition
openclaw browser wait --fn "window.dataLoaded === true"

# Combined wait (all conditions)
openclaw browser wait "#results" \
  --url "**/search**" \
  --load networkidle \
  --fn "document.querySelector('#results').children.length > 0"
```

### Handling Dynamic Content

```bash
# Infinite scroll - scroll and capture
for i in {1..5}; do
  openclaw browser scrollintoview e99
  sleep 1
done
openclaw browser snapshot --interactive

# AJAX-loaded content - wait then snapshot
openclaw browser click e45  # Trigger load
openclaw browser wait --fn "document.querySelectorAll('.item').length > 10"
openclaw browser snapshot
```

### Multi-Tab Workflows

```bash
# Open multiple tabs
openclaw browser tab new
openclaw browser open https://site1.com
TAB1=$(openclaw browser tabs --json | jq -r '.tabs[0].targetId')

openclaw browser tab new
openclaw browser open https://site2.com
TAB2=$(openclaw browser tabs --json | jq -r '.tabs[1].targetId')

# Switch between tabs
openclaw browser focus $TAB1
openclaw browser snapshot

openclaw browser focus $TAB2
openclaw browser snapshot
```

### Authenticated Sessions

```bash
# Method 1: HTTP Basic Auth
openclaw browser set credentials username password

# Method 2: Cookie-based auth
openclaw browser cookies set session "abc123" --url "https://example.com"

# Method 3: Token in headers
openclaw browser set headers --json '{"Authorization":"Bearer token123"}'

# Login via form then save session
openclaw browser open https://example.com/login
openclaw browser type e12 "user"
openclaw browser type e13 "pass" --submit
openclaw browser wait --url "**/dashboard"
openclaw browser cookies --json > ~/.openclaw/sessions/example.com.json
```

### Mobile/Device Emulation

```bash
# Emulate mobile device
openclaw browser set device "iPhone 14"
openclaw browser open https://example.com

# Custom viewport
openclaw browser set viewport 375 812
openclaw browser snapshot

# Reset to desktop
openclaw browser set device ""
```

## Data Extraction Patterns

### Pattern 1: Table Extraction

```bash
openclaw browser evaluate --fn '
  const rows = Array.from(document.querySelectorAll("table tr"));
  rows.map(row => {
    const cells = Array.from(row.querySelectorAll("td, th"));
    return cells.map(cell => cell.textContent.trim());
  });
'
```

### Pattern 2: List Scraping

```bash
openclaw browser evaluate --fn '
  Array.from(document.querySelectorAll(".article")).map(article => ({
    title: article.querySelector("h2")?.textContent,
    summary: article.querySelector(".summary")?.textContent,
    link: article.querySelector("a")?.href
  }));
'
```

### Pattern 3: Attribute Extraction

```bash
openclaw browser evaluate --fn '
  Array.from(document.querySelectorAll("img")).map(img => ({
    src: img.src,
    alt: img.alt,
    width: img.width,
    height: img.height
  }));
'
```

## Error Handling & Debugging

### When Actions Fail

1. **Re-snapshot after navigation**
   ```bash
   openclaw browser navigate https://example.com/new-page
   openclaw browser wait --load networkidle
   openclaw browser snapshot --interactive  # Get fresh refs
   ```

2. **Highlight element before clicking**
   ```bash
   openclaw browser highlight e12
   openclaw browser click e12
   ```

3. **Check console errors**
   ```bash
   openclaw browser console --level error
   openclaw browser errors
   ```

4. **Record trace for debugging**
   ```bash
   openclaw browser trace start
   # ... perform actions ...
   openclaw browser trace stop  # Returns trace file path
   ```

### Common Issues

**Element not found:**
- Wait for element: `openclaw browser wait "#element"`
- Check if in iframe: `openclaw browser snapshot --frame "iframe"`

**Element not clickable:**
- Scroll into view: `openclaw browser scrollintoview e12`
- Check coverage: `openclaw browser highlight e12`

**Stale element reference:**
- Re-snapshot after any navigation
- Use fresh refs for each action sequence

## Security Notes

- Browser profile is isolated but contains session data
- JavaScript evaluation (`evaluate`, `act kind=evaluate`) runs arbitrary code
- Treat saved cookies as sensitive data
- Keep Gateway on loopback or private network

## Reference Files

- [Advanced Scripts](references/scripts.md) - Complex automation patterns
- [Data Extraction](references/extraction.md) - Structured data extraction techniques
- [Monitoring](references/monitoring.md) - Page monitoring and alerting patterns

## Script Usage

Located in `scripts/`:

| Script | Purpose | Example |
|--------|---------|---------|
| `extract-data.js` | Structured data extraction | `./scripts/extract-data.js --url ... --selector ...` |
| `batch-scrape.js` | Multi-page batch operations | `./scripts/batch-scrape.js --urls ... --action ...` |
| `form-filler.js` | Automated form filling | `./scripts/form-filler.js --form-file ...` |
| `monitor-page.js` | Page change monitoring | `./scripts/monitor-page.js --url ... --interval ...` |
