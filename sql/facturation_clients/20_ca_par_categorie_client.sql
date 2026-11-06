-- CA HT par catégorie client (étiquettes du contact, sur la société cliente)
-- Visualisation : Barres horizontales (« Rangée ») ou Anneau
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
-- Un client avec plusieurs étiquettes compte dans chacune : la somme des
-- catégories peut donc dépasser le CA total. part_pct est calculée sur le CA total réel.
WITH factures AS (
  SELECT account_move.id, account_move.commercial_partner_id, account_move.amount_untaxed_signed
  FROM account_move
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  WHERE account_move.move_type IN ('out_invoice', 'out_refund')
    AND account_move.state = 'posted'
    AND EXTRACT(YEAR FROM account_move.invoice_date) =
        COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
    [[AND {{unite}}]]
),
lignes AS (
  SELECT
    COALESCE(c.name->>'fr_FR', c.name->>'en_US', 'Sans catégorie') AS categorie,
    f.commercial_partner_id,
    f.amount_untaxed_signed
  FROM factures f
  LEFT JOIN res_partner_res_partner_category_rel r ON r.partner_id = f.commercial_partner_id
  LEFT JOIN res_partner_category c                 ON c.id = r.category_id
)
SELECT
  categorie,
  COUNT(DISTINCT commercial_partner_id) AS nb_clients,
  SUM(amount_untaxed_signed)            AS ca_ht,
  ROUND(100.0 * SUM(amount_untaxed_signed)
        / NULLIF((SELECT SUM(amount_untaxed_signed) FROM factures), 0), 1) AS part_pct
FROM lignes
WHERE 1 = 1
  [[AND categorie = {{categorie}}]]
GROUP BY categorie
ORDER BY ca_ht DESC;
