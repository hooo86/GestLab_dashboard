-- CA HT par direction régionale (DR) et par mois
-- La DR d'une facture = son unité si elle est elle-même une DR (is_dr),
-- sinon la DR parente de l'unité (parent_dr_id).
-- Visualisation : Barres empilées ou Lignes (X = mois, Y = ca_ht, série = direction_regionale)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026) et {{dr}} (Texte)
SELECT
  date_trunc('month', account_move.invoice_date)::date AS mois,
  COALESCE(operating_unit.name, 'Sans DR')             AS direction_regionale,
  SUM(account_move.amount_untaxed_signed)              AS ca_ht
FROM account_move
LEFT JOIN operating_unit ou ON ou.id = account_move.operating_unit_id
-- "operating_unit" (sans alias) = la DR
LEFT JOIN operating_unit ON operating_unit.id =
  CASE WHEN COALESCE(ou.is_dr, false) THEN ou.id ELSE ou.parent_dr_id END
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND operating_unit.name = {{dr}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
