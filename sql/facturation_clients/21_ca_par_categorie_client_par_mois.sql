-- CA HT par catégorie client (family_customer) et par mois
-- Seuls les partenaires avec « is_customer » coché sont pris en compte.
-- Visualisation : Barres empilées ou Lignes (X = mois, Y = ca_ht, série = categorie)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
SELECT
  date_trunc('month', account_move.invoice_date)::date AS mois,
  COALESCE(s.name->>'fr_FR', s.name->>'en_US', p.family_customer, 'Sans catégorie') AS categorie,
  SUM(account_move.amount_untaxed_signed) AS ca_ht
FROM account_move
JOIN res_partner p ON p.id = account_move.commercial_partner_id AND p.is_customer
LEFT JOIN ir_model_fields_selection s
       ON s.value = p.family_customer
      AND s.field_id = (SELECT id FROM ir_model_fields
                        WHERE model = 'res.partner' AND name = 'family_customer')
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND EXTRACT(YEAR FROM account_move.invoice_date) =
      COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
  [[AND {{unite}}]]
  [[AND COALESCE(s.name->>'fr_FR', s.name->>'en_US', p.family_customer, 'Sans catégorie') = {{categorie}}]]
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
