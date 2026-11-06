-- Chiffre d'affaires facturé HT par mois (factures clients validées, avoirs déduits)
-- Graphique conseillé : barres
-- Filtre DR : {{dr}} (Texte, facultatif) = nom de la direction régionale
SELECT
  to_char(m.invoice_date, 'YYYY-MM') AS mois,
  SUM(m.amount_untaxed_signed)              AS ca_ht
FROM account_move m
WHERE m.move_type IN ('out_invoice', 'out_refund')
  AND m.state = 'posted'
  AND m.journal_id = 1  -- journal « Factures clients » uniquement
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = m.commercial_partner_id AND x.family_customer = 1005)
  -- Direction régionale de l'unité de la facture (l'unité elle-même si c'est une DR)
  [[AND EXISTS (SELECT 1 FROM operating_unit u_dr JOIN operating_unit d_dr ON d_dr.id = CASE WHEN COALESCE(u_dr.is_dr, false) THEN u_dr.id ELSE u_dr.parent_dr_id END WHERE u_dr.id = m.operating_unit_id AND d_dr.name = {{dr}})]]
GROUP BY 1
ORDER BY 1;
