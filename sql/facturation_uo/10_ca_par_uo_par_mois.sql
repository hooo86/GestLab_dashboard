-- CA HT facturé par unité opérationnelle et par mois
-- (factures clients validées, avoirs déduits)
-- Visualisation : Barres empilées (X = mois, Y = ca_ht, série = unite)
-- Filtres Metabase : {{annee}} et {{unite}} (voir README de ce dossier)
SELECT
  date_trunc('month', account_move.invoice_date)::date AS mois,
  COALESCE(operating_unit.name, 'Sans unité')         AS unite,
  SUM(account_move.amount_untaxed_signed)              AS ca_ht
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.commercial_partner_id IS DISTINCT FROM 1005  -- client interne exclu
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
