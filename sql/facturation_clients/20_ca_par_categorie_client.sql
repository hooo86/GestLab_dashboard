-- CA HT par catégorie client (champ « family_customer » de la société cliente → family.customer)
-- Seuls les clients (customer_rank > 0, case « client » d'Odoo) sont pris en compte.
-- Visualisation : Tableau (la dernière ligne TOTAL fausserait un graphique)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026), {{categorie}} (Texte),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année : année en cours.
-- Dernière ligne : TOTAL
WITH detail AS (
  SELECT
    cat.categorie AS categorie,
    COUNT(DISTINCT p.id)                     AS nb_clients,
    SUM(account_move.amount_untaxed_signed)  AS ca_ht,
    ROUND(100.0 * SUM(account_move.amount_untaxed_signed)
          / NULLIF(SUM(SUM(account_move.amount_untaxed_signed)) OVER (), 0), 1) AS part_pct
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
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    AND TRUE /* perimetre:account_move */  -- unités de l'utilisateur (remplacé par le script de copie)
    AND EXTRACT(YEAR FROM account_move.invoice_date) =
        COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
    [[AND {{unite}}]]
    [[AND cat.categorie = {{categorie}}]]
  GROUP BY 1
)
SELECT * FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM(nb_clients), SUM(ca_ht), 100.0
  FROM detail
) t
ORDER BY (categorie = 'TOTAL'), ca_ht DESC;
