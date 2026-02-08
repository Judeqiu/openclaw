# Advanced Data Extraction Patterns

## Pattern 1: E-commerce Product Scraping

```javascript
// Extract product information
const products = Array.from(document.querySelectorAll('.product')).map(product => ({
  name: product.querySelector('.product-title')?.textContent?.trim(),
  price: product.querySelector('.price')?.textContent?.trim(),
  currency: product.querySelector('.price')?.getAttribute('data-currency'),
  image: product.querySelector('img')?.src,
  link: product.querySelector('a')?.href,
  rating: product.querySelector('.rating')?.textContent,
  inStock: !product.querySelector('.out-of-stock')
}));
```

## Pattern 2: News Article Extraction

```javascript
// Extract article content
const articles = Array.from(document.querySelectorAll('article')).map(article => ({
  headline: article.querySelector('h1, h2, .headline')?.textContent?.trim(),
  author: article.querySelector('.author, [rel="author"]')?.textContent?.trim(),
  date: article.querySelector('time')?.getAttribute('datetime'),
  summary: article.querySelector('.summary, .excerpt')?.textContent?.trim(),
  content: article.querySelector('.content, .article-body')?.textContent?.trim()?.slice(0, 500),
  tags: Array.from(article.querySelectorAll('.tag, [rel="tag"]')).map(t => t.textContent)
}));
```

## Pattern 3: Table Data Extraction

```javascript
// Convert HTML table to structured data
const tables = Array.from(document.querySelectorAll('table')).map((table, i) => {
  const headers = Array.from(table.querySelectorAll('th')).map(th => th.textContent.trim());
  const rows = Array.from(table.querySelectorAll('tr')).slice(1).map(row => {
    const cells = Array.from(row.querySelectorAll('td'));
    const rowData = {};
    headers.forEach((header, index) => {
      rowData[header] = cells[index]?.textContent?.trim();
    });
    return rowData;
  });
  return { tableIndex: i, headers, rows };
});
```

## Pattern 4: JSON-LD Structured Data

```javascript
// Extract JSON-LD structured data
const jsonLd = Array.from(document.querySelectorAll('script[type="application/ld+json"]'))
  .map(script => {
    try {
      return JSON.parse(script.textContent);
    } catch (e) {
      return null;
    }
  })
  .filter(Boolean);

// Get product/schema.org data
const productData = jsonLd.find(d => d['@type'] === 'Product');
const articleData = jsonLd.find(d => d['@type'] === 'Article');
```

## Pattern 5: Social Media Metrics

```javascript
// Extract engagement metrics
const metrics = {
  likes: document.querySelector('.likes-count')?.textContent,
  shares: document.querySelector('.shares-count')?.textContent,
  comments: document.querySelector('.comments-count')?.textContent,
  views: document.querySelector('.views-count')?.textContent,
  
  // Parse numbers with suffixes (K, M, B)
  parseCount: (str) => {
    if (!str) return 0;
    const num = parseFloat(str.replace(/,/g, ''));
    if (str.includes('K')) return num * 1000;
    if (str.includes('M')) return num * 1000000;
    if (str.includes('B')) return num * 1000000000;
    return num;
  }
};
```

## Pattern 6: Infinite Scroll Handling

```bash
# Script to scroll and collect data
#!/bin/bash
URL="$1"
SELECTOR="$2"
SCROLLS="${3:-5}"

openclaw browser open "$URL"
sleep 2

for i in $(seq 1 $SCROLLS); do
  echo "Scroll $i/$SCROLLS"
  
  # Scroll to bottom
  openclaw browser evaluate --fn 'window.scrollTo(0, document.body.scrollHeight)'
  sleep 2
  
  # Wait for new content
  openclaw browser wait --fn 'document.readyState === "complete"'
done

# Extract all data
openclaw browser evaluate --fn "
  Array.from(document.querySelectorAll('$SELECTOR')).map(el => ({
    text: el.textContent?.trim(),
    href: el.href
  }))
" --json
```

## Pattern 7: Multi-Step Form Extraction

```javascript
// Extract form structure and values
const forms = Array.from(document.querySelectorAll('form')).map(form => {
  const fields = Array.from(form.querySelectorAll('input, select, textarea')).map(field => ({
    name: field.name,
    type: field.type || field.tagName.toLowerCase(),
    required: field.required,
    placeholder: field.placeholder,
    value: field.value,
    options: field.tagName === 'SELECT' 
      ? Array.from(field.options).map(o => ({ value: o.value, text: o.text }))
      : null,
    validation: field.pattern || field.min || field.max || null
  }));
  
  return {
    action: form.action,
    method: form.method,
    fields: fields.filter(f => f.name)
  };
});
```

## Pattern 8: API Endpoint Discovery

```javascript
// Monitor network requests for API endpoints
const apiEndpoints = performance.getEntriesByType('resource')
  .filter(r => r.name.includes('/api/') || r.name.includes('/graphql'))
  .map(r => ({
    url: r.name,
    method: r.initiatorType,
    duration: r.duration,
    size: r.transferSize
  }));

// Check for GraphQL
const graphqlEndpoints = apiEndpoints.filter(e => 
  e.url.includes('graphql') || e.url.includes('/gql')
);
```

## Pattern 9: Image Gallery Extraction

```javascript
// Extract image galleries
const images = Array.from(document.querySelectorAll('img')).map(img => ({
  src: img.src,
  srcset: img.srcset,
  sizes: img.sizes,
  alt: img.alt,
  width: img.naturalWidth,
  height: img.naturalHeight,
  lazy: img.loading === 'lazy',
  // Find high-res version
  highRes: img.src?.replace(/_(small|medium|thumb)\./, '_large.')
}));

// Filter by size (min 200px)
const significantImages = images.filter(img => 
  img.width > 200 && img.height > 200
);
```

## Pattern 10: Search Results Scraping

```javascript
// Extract search results
const results = Array.from(document.querySelectorAll('.result, .search-result, [data-result]')).map((result, i) => ({
  position: i + 1,
  title: result.querySelector('h3, .title')?.textContent?.trim(),
  url: result.querySelector('a')?.href,
  displayUrl: result.querySelector('.url, cite')?.textContent,
  snippet: result.querySelector('.snippet, .description')?.textContent?.trim(),
  featured: result.classList.contains('featured') || result.matches('[data-featured]'),
  // Check for rich results
  hasImage: !!result.querySelector('img'),
  hasRating: !!result.querySelector('.rating, [data-rating]'),
  hasPrice: !!result.querySelector('.price')
}));
```
