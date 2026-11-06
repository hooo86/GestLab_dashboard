-- CA HT facturé par unité opérationnelle et par mois
-- (factures clients validées, avoirs déduits)
-- Visualisation : Barres empilées (X = mois, Y = ca_ht, série = unite)
-- Filtres Metabase : {{annee}} et {{unite}} (voir README de ce dossier)
SELECT
  to_char(account_move.invoice_date, 'YYYY-MM') AS mois,
  COALESCE(operating_unit.name, 'Sans unité')         AS unite,
  SUM(account_move.amount_untaxed_signed)              AS ca_ht
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
