-- CA HT par direction régionale (DR) et par mois
-- La DR d'une facture = son unité si elle est elle-même une DR (is_dr),
-- sinon la DR parente de l'unité (parent_dr_id).
-- Visualisation : Barres empilées ou Lignes (X = mois, Y = ca_ht, série = direction_regionale)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026) et {{dr}} (Texte), {{unite}} (Filtre de champ → Operating Unit → Name)
SELECT
  to_char(account_move.invoice_date, 'YYYY-MM') AS mois,
  COALESCE(dr.name, 'Sans DR')             AS direction_regionale,
  SUM(account_move.amount_untaxed_signed)              AS ca_ht
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id   -- unité de la facture
LEFT JOIN operating_unit dr ON dr.id =   -- sa DR : l'unité elle-même si c'est une DR, sinon sa DR parente
  CASE WHEN COALESCE(operating_unit.is_dr, false) THEN operating_unit.id ELSE operating_unit.parent_dr_id END
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
  AND TRUE /* perimetre:account_move */  -- unités de l'utilisateur (remplacé par le script de copie)
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND dr.name = {{dr}}]]
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
