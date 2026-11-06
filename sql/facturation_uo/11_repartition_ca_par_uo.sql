-- Répartition du CA HT entre unités opérationnelles, avec la part en %
-- Visualisation : Camembert / Anneau (dimension = unite, mesure = ca_ht)
--                 ou Tableau pour voir les pourcentages
-- Filtres Metabase : {{annee}} et {{unite}}
SELECT
  COALESCE(operating_unit.name, 'Sans unité')  AS unite,
  COUNT(*) FILTER (WHERE account_move.move_type = 'out_invoice') AS nb_factures,
  SUM(account_move.amount_untaxed_signed)       AS ca_ht,
  ROUND(100.0 * SUM(account_move.amount_untaxed_signed)
        / NULLIF(SUM(SUM(account_move.amount_untaxed_signed)) OVER (), 0), 1) AS part_pct
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.commercial_partner_id IS DISTINCT FROM 1005  -- client interne exclu
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND {{unite}}]]
GROUP BY 1
ORDER BY ca_ht DESC;
