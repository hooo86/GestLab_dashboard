-- CA HT par catégorie client et par mois
-- Visualisation : Barres empilées ou Lignes (X = mois, Y = ca_ht, série = categorie)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
SELECT
  date_trunc('month', account_move.invoice_date)::date             AS mois,
  COALESCE(c.name->>'fr_FR', c.name->>'en_US', 'Sans catégorie')   AS categorie,
  SUM(account_move.amount_untaxed_signed)                          AS ca_ht
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
LEFT JOIN res_partner_res_partner_category_rel r ON r.partner_id = account_move.commercial_partner_id
LEFT JOIN res_partner_category c                 ON c.id = r.category_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND EXTRACT(YEAR FROM account_move.invoice_date) =
      COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
  [[AND {{unite}}]]
  [[AND COALESCE(c.name->>'fr_FR', c.name->>'en_US', 'Sans catégorie') = {{categorie}}]]
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
