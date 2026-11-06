-- CA HT facturé par unité opérationnelle et par mois
-- (factures clients validées, avoirs déduits)
-- Visualisation : Barres empilées (X = mois, Y = ca_ht, série = unite)
-- Filtres Metabase : {{annee}} et {{unite}} (voir README de ce dossier)
-- Filtre DR : {{dr}} (Texte, facultatif) = nom de la direction régionale
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
  -- Direction régionale de l'unité de la facture (l'unité elle-même si c'est une DR)
  [[AND EXISTS (SELECT 1 FROM operating_unit u_dr JOIN operating_unit d_dr ON d_dr.id = CASE WHEN COALESCE(u_dr.is_dr, false) THEN u_dr.id ELSE u_dr.parent_dr_id END WHERE u_dr.id = account_move.operating_unit_id AND d_dr.name = {{dr}})]]
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
