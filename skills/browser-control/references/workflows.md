# Browser Automation Workflows

## Workflow 1: Login and Session Persistence

```bash
#!/bin/bash
# login-and-save-session.sh

SITE="$1"
USERNAME="$2"
PASSWORD="$3"
SESSION_FILE="${4:-$HOME/.openclaw/sessions/$(echo $SITE | tr '/:' '_').json}"

echo "Logging into $SITE..."

# Navigate to login
openclaw browser open "$SITE/login"
openclaw browser wait --load networkidle

# Get snapshot to find fields
openclaw browser snapshot --interactive --json > /tmp/login-snapshot.json

# Find username/password fields (using common selectors)
USERNAME_REF=$(openclaw browser evaluate --fn '
  const el = document.querySelector("input[type=email], input[name=email], input[name=username], #username, #email");
  el?.closest("[ref]")?.getAttribute("ref") || "e12";
')

PASSWORD_REF=$(openclaw browser evaluate --fn '
  const el = document.querySelector("input[type=password], input[name=password], #password");
  el?.closest("[ref]")?.getAttribute("ref") || "e13";
')

# Fill credentials
openclaw browser type "$USERNAME_REF" "$USERNAME"
openclaw browser type "$PASSWORD_REF" "$PASSWORD" --submit

# Wait for redirect
openclaw browser wait --load networkidle

# Save session
openclaw browser cookies --json > "$SESSION_FILE"
echo "Session saved to: $SESSION_FILE"
```

## Workflow 2: Bulk Screenshot Capture

```bash
#!/bin/bash
# bulk-screenshot.sh

URLS_FILE="$1"
OUTPUT_DIR="${2:-./screenshots}"
mkdir -p "$OUTPUT_DIR"

while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  [[ "$url" =~ ^# ]] && continue
  
  filename=$(echo "$url" | tr '/:' '_' | cut -c1-100)
  echo "Capturing: $url"
  
  openclaw browser open "$url"
  openclaw browser wait --load networkidle
  sleep 1
  
  openclaw browser screenshot --full-page --output "$OUTPUT_DIR/${filename}.png"
  echo "Saved: $OUTPUT_DIR/${filename}.png"
done < "$URLS_FILE"
```

## Workflow 3: Price Monitoring

```bash
#!/bin/bash
# price-monitor.sh

PRODUCT_URL="$1"
PRICE_SELECTOR="$2"
THRESHOLD="$3"
NOTIFY_CMD="$4"

echo "Monitoring price at: $PRODUCT_URL"
echo "Selector: $PRICE_SELECTOR"

openclaw browser open "$PRODUCT_URL"
openclaw browser wait --load networkidle

PRICE_TEXT=$(openclaw browser evaluate --fn "
  document.querySelector('$PRICE_SELECTOR')?.textContent?.trim() || 'NOT_FOUND'
")

# Extract numeric price
PRICE=$(echo "$PRICE_TEXT" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)

echo "Current price: $PRICE"
echo "Threshold: $THRESHOLD"

if (( $(echo "$PRICE <= $THRESHOLD" | bc -l) )); then
  echo "🎉 Price dropped below threshold!"
  if [ -n "$NOTIFY_CMD" ]; then
    $NOTIFY_CMD "$PRODUCT_URL" "$PRICE"
  fi
fi
```

## Workflow 4: Form Testing

```bash
#!/bin/bash
# test-form.sh

FORM_URL="$1"
TEST_DATA_FILE="$2"

echo "Testing form at: $FORM_URL"

# Load test data
declare -A TEST_DATA
while IFS='=' read -r key value; do
  TEST_DATA[$key]="$value"
done < "$TEST_DATA_FILE"

# Open form
openclaw browser open "$FORM_URL"
openclaw browser wait --load networkidle

# Get form fields
FIELDS=$(openclaw browser evaluate --json --fn '
  Array.from(document.querySelectorAll("input[name], select[name], textarea[name]"))
    .map(f => ({ name: f.name, type: f.type || f.tagName.toLowerCase(), required: f.required }))
')

echo "Found fields:"
echo "$FIELDS" | jq -r '.result[] | "  - \(.name) (\(.type))\(.required ? " [required]" : "")"'

# Fill with test data
for field in "${!TEST_DATA[@]}"; do
  value="${TEST_DATA[$field]}"
  echo "Filling: $field = $value"
  
  # Find ref for field
  REF=$(openclaw browser evaluate --fn "
    const el = document.querySelector('[name=\"$field\"]');
    el?.closest('[ref]')?.getAttribute('ref');
  ")
  
  if [ -n "$REF" ]; then
    openclaw browser type "$REF" "$value"
  fi
done

# Screenshot before submit
openclaw browser screenshot --output /tmp/form-filled.png

# Submit
openclaw browser evaluate --fn '
  document.querySelector("form")?.submit();
'

# Wait for response
openclaw browser wait --load networkidle

# Screenshot after submit
openclaw browser screenshot --output /tmp/form-submitted.png

echo "Test complete! Check screenshots:"
echo "  - /tmp/form-filled.png"
echo "  - /tmp/form-submitted.png"
```

## Workflow 5: Content Comparison

```bash
#!/bin/bash
# compare-content.sh

URL1="$1"
URL2="$2"
SELECTOR="${3:-body}"

echo "Comparing:"
echo "  A: $URL1"
echo "  B: $URL2"

# Get content from first URL
openclaw browser open "$URL1"
openclaw browser wait --load networkidle
CONTENT1=$(openclaw browser evaluate --fn "
  document.querySelector('$SELECTOR')?.textContent?.trim();
")

# Get content from second URL
openclaw browser open "$URL2"
openclaw browser wait --load networkidle
CONTENT2=$(openclaw browser evaluate --fn "
  document.querySelector('$SELECTOR')?.textContent?.trim();
")

# Compare
if [ "$CONTENT1" == "$CONTENT2" ]; then
  echo "✅ Content matches"
else
  echo "❌ Content differs"
  
  # Save diff
  echo "$CONTENT1" > /tmp/content_a.txt
  echo "$CONTENT2" > /tmp/content_b.txt
  diff /tmp/content_a.txt /tmp/content_b.txt > /tmp/content_diff.txt
  
  echo "Diff saved to: /tmp/content_diff.txt"
fi

# Compare screenshots
openclaw browser screenshot --full-page --output /tmp/page_b.png

openclaw browser open "$URL1"
openclaw browser wait --load networkidle
openclaw browser screenshot --full-page --output /tmp/page_a.png

echo "Screenshots saved:"
echo "  - /tmp/page_a.png"
echo "  - /tmp/page_b.png"
```

## Workflow 6: PDF Generation Pipeline

```bash
#!/bin/bash
# generate-pdfs.sh

URLS_FILE="$1"
OUTPUT_DIR="${2:-./pdfs}"
mkdir -p "$OUTPUT_DIR"

while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  [[ "$url" =~ ^# ]] && continue
  
  filename=$(echo "$url" | tr '/:' '_' | cut -c1-100).pdf
  
  echo "Generating PDF: $url"
  
  openclaw browser open "$url"
  openclaw browser wait --load networkidle
  
  # Optional: Apply print styles
  openclaw browser evaluate --fn '
    const style = document.createElement("style");
    style.textContent = `
      @media print {
        nav, footer, .ads, .sidebar { display: none !important; }
        body { font-size: 12pt; }
      }
    `;
    document.head.appendChild(style);
  '
  
  openclaw browser pdf --output "$OUTPUT_DIR/$filename"
  echo "Saved: $OUTPUT_DIR/$filename"
done < "$URLS_FILE"
```

## Workflow 7: Accessibility Audit

```bash
#!/bin/bash
# a11y-audit.sh

URL="$1"

echo "Running accessibility audit: $URL"

openclaw browser open "$URL"
openclaw browser wait --load networkidle

# Check for common accessibility issues
RESULTS=$(openclaw browser evaluate --json --fn '
  const issues = [];
  
  // Images without alt
  document.querySelectorAll("img:not([alt])").forEach(img => {
    issues.push({ type: "missing-alt", element: "img", src: img.src?.slice(0, 50) });
  });
  
  // Forms without labels
  document.querySelectorAll("input:not([aria-label]):not([aria-labelledby]):not([id])").forEach(input => {
    issues.push({ type: "missing-label", element: "input", name: input.name });
  });
  
  // Low contrast (basic check)
  const lowContrastElements = Array.from(document.querySelectorAll("*")).filter(el => {
    const style = window.getComputedStyle(el);
    const color = style.color;
    const bg = style.backgroundColor;
    return color.includes("rgb(200") && bg.includes("rgb(255");
  }).length;
  
  // Missing lang attribute
  const missingLang = !document.documentElement.lang;
  
  // Skip links
  document.querySelectorAll("a").forEach(a => {
    if (!a.textContent.trim() && !a.getAttribute("aria-label")) {
      issues.push({ type: "empty-link", element: "a", href: a.href?.slice(0, 50) });
    }
  });
  
  return {
    totalIssues: issues.length,
    categories: {
      missingAlt: issues.filter(i => i.type === "missing-alt").length,
      missingLabel: issues.filter(i => i.type === "missing-label").length,
      emptyLink: issues.filter(i => i.type === "empty-link").length,
      potentialContrastIssues: lowContrastElements,
      missingLang
    },
    issues: issues.slice(0, 20) // First 20 issues
  };
')

echo "$RESULTS" | jq '.'
```
