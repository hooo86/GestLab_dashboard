-- CA HT par catégorie client (champ « family_customer » de la société cliente)
-- Seuls les partenaires avec « is_customer » coché sont pris en compte.
-- Visualisation : Barres horizontales (« Rangée ») ou Anneau
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
SELECT
  COALESCE(s.name->>'fr_FR', s.name->>'en_US', p.family_customer, 'Sans catégorie') AS categorie,
  COUNT(DISTINCT p.id)                     AS nb_clients,
  SUM(account_move.amount_untaxed_signed)  AS ca_ht,
  ROUND(100.0 * SUM(account_move.amount_untaxed_signed)
        / NULLIF(SUM(SUM(account_move.amount_untaxed_signed)) OVER (), 0), 1) AS part_pct
FROM account_move
JOIN res_partner p ON p.id = account_move.commercial_partner_id AND p.is_customer
-- Libellé de la catégorie, tel qu'affiché dans Odoo
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
GROUP BY 1
ORDER BY ca_ht DESC;
