-- CA HT par catégorie client (family_customer) et par mois
-- Seuls les clients (customer_rank > 0, case « client » d'Odoo) sont pris en compte.
-- Visualisation : Barres empilées ou Lignes (X = mois, Y = ca_ht, série = categorie)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
SELECT
  date_trunc('month', account_move.invoice_date)::date AS mois,
  cat.categorie AS categorie,
  SUM(account_move.amount_untaxed_signed) AS ca_ht
FROM account_move
JOIN res_partner p ON p.id = account_move.commercial_partner_id AND p.customer_rank > 0
-- Catégorie : lien vers family.customer (nom traduisible ou non)
LEFT JOIN family_customer fc ON fc.id = p.family_customer
LEFT JOIN LATERAL (
  SELECT COALESCE(
    CASE WHEN jsonb_typeof(to_jsonb(fc.name)) = 'object'
         THEN COALESCE(to_jsonb(fc.name)->>'fr_FR', to_jsonb(fc.name)->>'en_US')
         ELSE to_jsonb(fc.name)#>>'{}' END,
    'Sans catégorie') AS categorie
) cat ON true
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.commercial_partner_id IS DISTINCT FROM 1005  -- client interne exclu
  AND EXTRACT(YEAR FROM account_move.invoice_date) =
      COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
  [[AND {{unite}}]]
  [[AND cat.categorie = {{categorie}}]]
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
