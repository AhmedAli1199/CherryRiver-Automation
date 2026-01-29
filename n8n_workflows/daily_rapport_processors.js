// ============================================
// N8N CODE NODES FOR DAILY RAPPORT PROCESSING
// Copy each section into a separate Code node in n8n
// ============================================

// HELPER FUNCTION - Add this to ALL Code nodes
// Excel serial date to ISO date string
function excelToDate(serial) {
  if (!serial || serial === '' || serial === '-') return null;
  // Excel epoch: 1900-01-01, but with leap year bug
  // 25569 = days between 1900-01-01 and 1970-01-01
  const date = new Date((serial - 25569) * 86400 * 1000);
  return date.toISOString().split('T')[0]; // Returns 'YYYY-MM-DD'
}

// ============================================
// PATH 1: INVENTAIRE_CD (Warehouse Inventory)
// ============================================
// Put this in a Code node after the webhook path for Inventaire_CD

const items = $input.all();
const transformed = [];

for (const item of items) {
  const data = item.json;

  // Parse boolean fields
  const isBlocked = data['Blocage (ds)'] === 'Article bloqué';
  const isOnline = (data['Statut SAQ.com'] || '').trim() === 'En ligne';
  const riskSharing = (data['Partage de risque'] || '').trim() === 'Partage de Risque';

  transformed.push({
    json: {
      code_saq: String(data['No article']),
      product_name: data['Article (ds)'],
      type_listing: data['Type listing (cd)'],
      uvc: data['UVC'] || 12,
      is_blocked: isBlocked,
      is_online: isOnline,
      risk_sharing: riskSharing,
      no_fournisseur: data['No fournisseur achat'],
      inventaire_cdm: data['Inventaire_CDM (cs)'] || 0,
      inv_alloc_cdm: data['Inv. ap. allocations CDM (cs)'] || 0,
      inventaire_cdq: data['Inventaire dispo_CDQ (cs)'] || 0,
      date_inventaire: excelToDate(data['Date inventaire'])
    }
  });
}

return transformed;


// ============================================
// PATH 2: INV_SUCC_BD (Store Inventory)
// ============================================
// Put this in a Code node after the webhook path for Inv_SUCC_BD

const items = $input.all();
const transformed = [];

for (const item of items) {
  const data = item.json;

  transformed.push({
    json: {
      code_saq: String(data['No article']),
      product_name: data['Article (ds)'],
      type_listing: data['Type listing (cd)'],
      store_id: String(data['Succursale/service/Entrepôt (id)']),
      store_name: data['Succursale/service/Entrepôt (nom)'],
      banner: data['Bannière (cd)'],
      qty_bottles: data['Inv (bt)'] || 0,
      date_inventaire: excelToDate(data['Date Inventaire_succ'])
    }
  });
}

return transformed;


// ============================================
// PATH 3: STATUT_COMMANDE (Order Status)
// ============================================
// Put this in a Code node after the webhook path for Statut_Commande

const items = $input.all();
const transformed = [];

for (const item of items) {
  const data = item.json;

  transformed.push({
    json: {
      no_commande: String(data['No document']),
      type_document: data['Type document (cd)'],
      code_saq: String(data['No article']),
      product_name: data['Article (ds)'],
      type_listing: data['Type listing (cd)'],
      qty_commandee: data['Qté commandée - BC'] || 0,
      destination: data['Destination'],
      no_fournisseur: data['No fournisseur'],
      date_emission: excelToDate(data['Dt Émission']),
      date_expedition_demandee: excelToDate(data["Dt d'expédition demandée"]),
      date_pret_fournisseur: excelToDate(data['Dt prêt Fournisseur']),
      date_depart_reel: excelToDate(data['Dt réelle départ']),
      eta_confirme: excelToDate(data['ETA Confirmé']),
      statut: data['Statut']
    }
  });
}

return transformed;
