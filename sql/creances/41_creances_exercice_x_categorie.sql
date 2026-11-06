-- Créances clients à une date d'arrêté :
-- EXERCICE DE LA FACTURE en lignes, CLASSE CLIENT en colonnes, totaux compris
-- Exercice = année de la date de facturation.
-- Créance = TTC de la facture − règlements lettrés (encaissements, avoirs, autres)
--           dont la date d'effet est au plus tard à la date d'arrêté
--           (date d'effet = date du règlement, ou date de facture si le règlement est antérieur).
-- Résultat sur 3 colonnes (exercice, categorie, creances) :
--   colonne « TOTAL » = total de l'exercice, ligne « TOTAL » = total de la catégorie.
-- Visualisation : Tableau → ⚙️ → activer « Pivoter le tableau »
--   (colonne de pivot = categorie, cellule = creances)
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}  Date : date de la situation (sans valeur : aujourd'hui)
--   {{exercice}}     Nombre : un seul exercice de facture
--   {{categorie}}    Texte
--   {{unite}}        Filtre de champ → Operating Unit → Name
-- Filtre DR : {{dr}} (Texte, facultatif) = nom de la direction régionale
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
factures AS (
  SELECT
    account_move.id,
    account_move.invoice_date,
    EXTRACT(YEAR FROM account_move.invoice_date)::int AS exercice,
    cat.categorie,
    account_move.amount_total_signed AS montant
  FROM account_move
  CROSS JOIN parametres
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  LEFT JOIN res_partner p      ON p.id = account_move.commercial_partner_id
  LEFT JOIN family_customer fc ON fc.id = p.family_customer
  LEFT JOIN LATERAL (
    SELECT COALESCE(
      CASE WHEN jsonb_typeof(to_jsonb(fc.name)) = 'object'
           THEN COALESCE(to_jsonb(fc.name)->>'fr_FR', to_jsonb(fc.name)->>'en_US')
           ELSE to_jsonb(fc.name)#>>'{}' END,
      'Sans catégorie') AS categorie
  ) cat ON true
  WHERE account_move.move_type = 'out_invoice'
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND account_move.invoice_date <= parametres.date_arrete
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    -- Direction régionale de l'unité de la facture (l'unité elle-même si c'est une DR)
    [[AND EXISTS (SELECT 1 FROM operating_unit u_dr JOIN operating_unit d_dr ON d_dr.id = CASE WHEN COALESCE(u_dr.is_dr, false) THEN u_dr.id ELSE u_dr.parent_dr_id END WHERE u_dr.id = account_move.operating_unit_id AND d_dr.name = {{dr}})]]
    [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{exercice}}]]
    [[AND cat.categorie = {{categorie}}]]
    [[AND {{unite}}]]
),
reglements AS (
  -- Ce qui a été lettré sur chaque facture, jusqu'à la date d'arrêté
  SELECT inv.move_id AS facture_id, SUM(apr.amount) AS montant
  FROM account_partial_reconcile apr
  JOIN account_move_line inv ON inv.id = apr.debit_move_id
  JOIN factures f            ON f.id = inv.move_id
  JOIN account_move_line cp  ON cp.id = apr.credit_move_id
  CROSS JOIN parametres
  WHERE cp.parent_state = 'posted'
    AND GREATEST(cp.date, f.invoice_date) <= parametres.date_arrete
  GROUP BY inv.move_id
),
restes AS (
  SELECT f.exercice, f.categorie, f.montant - COALESCE(r.montant, 0) AS creance
  FROM factures f
  LEFT JOIN reglements r ON r.facture_id = f.id
  WHERE f.montant - COALESCE(r.montant, 0) <> 0
)
SELECT
  CASE WHEN GROUPING(exercice)  = 1 THEN 'TOTAL' ELSE 'Exercice ' || exercice::text END AS exercice,
  CASE WHEN GROUPING(categorie) = 1 THEN 'TOTAL' ELSE categorie END      AS categorie,
  SUM(creance)                                                          AS creances
FROM restes
GROUP BY GROUPING SETS ((exercice, categorie), (exercice), (categorie), ())
-- Ordre : d'abord le détail, puis la ligne TOTAL, puis la colonne TOTAL
ORDER BY GROUPING(categorie), GROUPING(exercice), restes.exercice, restes.categorie;
