// ============================================
// N8N CODE NODE: Unpivot ID Foods Forecast CSV
// ============================================
// Input CSV format (wide):
//   Material, Material Description, DESCRIPTION, JAN/26, FEB/26, MAR/26, ...
//
// Output format (long/unpivoted):
//   One row per product per month
// ============================================

const items = $input.all();
const results = [];
const now = new Date().toISOString(); // forecast_version = upload timestamp

// Month mapping: CSV column header → month number
const monthMap = {
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
  'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
  'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
};

for (const item of items) {
  const data = item.json;
  const idFoodsCode = String(data['Material']);
  const productName = data['Material Description'];

  // Loop through all columns that match the pattern MON/YY
  for (const [key, value] of Object.entries(data)) {
    const match = key.match(/^([A-Z]{3})\/(\d{2})$/);
    if (!match) continue;

    const monthStr = match[1];
    const yearStr = match[2];
    const month = monthMap[monthStr];
    const year = 2000 + parseInt(yearStr); // "26" → 2026

    if (!month) continue;

    results.push({
      json: {
        id_foods_code: idFoodsCode,
        product_name: productName,
        forecast_year: year,
        forecast_month: month,
        qty_forecast: parseInt(value) || 0,
        forecast_version: now,
        uploaded_by: 'Alyssa'
      }
    });
  }
}

return results;


// ============================================
// STEP 2: UPSERT PRODUCTS (run before forecasts)
// ============================================
// Separate Code node to extract unique products

const items = $input.all();
const seen = new Set();
const products = [];

for (const item of items) {
  const code = item.json.id_foods_code;
  if (seen.has(code)) continue;
  seen.add(code);
  products.push({
    json: {
      id_foods_code: code,
      product_name: item.json.product_name
    }
  });
}

return products;
