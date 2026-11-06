-- Créances clients à une date d'arrêté, par EXERCICE DE LA FACTURE (lignes)
-- et par ÉTIQUETTE client (colonnes)
-- Étiquettes : OPGI, AADL, ENPI, DEP, DUAC, DL, VN, CTC ; « Autres » = client sans aucune de ces étiquettes.
-- Un client qui a plusieurs de ces étiquettes est compté dans la première de la liste.
-- Créance = TTC de la facture − règlements lettrés (encaissements, avoirs, autres) dont la
-- date d'effet (date du règlement, ou date de facture si antérieure) ≤ date d'arrêté.
-- Visualisation : Tableau (colonnes fixes, pas de pivot). Dernière ligne : TOTAL
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}  Date (sans valeur : aujourd'hui)
--   {{exercice}}     Nombre : exercice de la facture
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
    COALESCE(etq.code, 'Autres')                      AS etiquette,
    account_move.amount_total_signed                  AS montant
  FROM account_move
  CROSS JOIN parametres
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  -- Étiquette du client (contact ou société) parmi la liste, si plusieurs, la première de la liste
  LEFT JOIN LATERAL (
    SELECT e.code
    FROM (VALUES (1, 'OPGI'), (2, 'AADL'), (3, 'ENPI'), (4, 'DEP'), (5, 'DUAC'), (6, 'DL'), (7, 'VN'), (8, 'CTC')) AS e(ordre, code)
    WHERE EXISTS (
      SELECT 1
      FROM res_partner_res_partner_category_rel r
      JOIN res_partner_category c ON c.id = r.category_id
      WHERE r.partner_id IN (account_move.commercial_partner_id, account_move.partner_id)
        AND upper(trim(CASE WHEN jsonb_typeof(to_jsonb(c.name)) = 'object'
                            THEN COALESCE(to_jsonb(c.name)->>'fr_FR', to_jsonb(c.name)->>'en_US')
                            ELSE to_jsonb(c.name)#>>'{}' END)) = e.code)
    ORDER BY e.ordre
    LIMIT 1
  ) etq ON true
  WHERE account_move.move_type = 'out_invoice'
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    -- Direction régionale de l'unité de la facture (l'unité elle-même si c'est une DR)
    [[AND EXISTS (SELECT 1 FROM operating_unit u_dr JOIN operating_unit d_dr ON d_dr.id = CASE WHEN COALESCE(u_dr.is_dr, false) THEN u_dr.id ELSE u_dr.parent_dr_id END WHERE u_dr.id = account_move.operating_unit_id AND d_dr.name = {{dr}})]]
    AND account_move.invoice_date <= parametres.date_arrete
    [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{exercice}}]]
    [[AND {{unite}}]]
),
reglements AS (
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
lignes AS (
  SELECT f.exercice, f.etiquette, f.montant - COALESCE(r.montant, 0) AS creance
  FROM factures f
  LEFT JOIN reglements r ON r.facture_id = f.id
  WHERE f.montant - COALESCE(r.montant, 0) <> 0
),
detail AS (
  SELECT
    exercice,
    SUM(creance) FILTER (WHERE etiquette = 'OPGI') AS "OPGI",
    SUM(creance) FILTER (WHERE etiquette = 'AADL') AS "AADL",
    SUM(creance) FILTER (WHERE etiquette = 'ENPI') AS "ENPI",
    SUM(creance) FILTER (WHERE etiquette = 'DEP') AS "DEP",
    SUM(creance) FILTER (WHERE etiquette = 'DUAC') AS "DUAC",
    SUM(creance) FILTER (WHERE etiquette = 'DL') AS "DL",
    SUM(creance) FILTER (WHERE etiquette = 'VN') AS "VN",
    SUM(creance) FILTER (WHERE etiquette = 'CTC') AS "CTC",
    SUM(creance) FILTER (WHERE etiquette = 'Autres') AS "Autres",
    SUM(creance) AS "TOTAL"
  FROM lignes
  GROUP BY exercice
)
SELECT * FROM (
  SELECT 'Exercice ' || exercice::text AS exercice, "OPGI", "AADL", "ENPI", "DEP", "DUAC", "DL", "VN", "CTC", "Autres", "TOTAL"
  FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM("OPGI"), SUM("AADL"), SUM("ENPI"), SUM("DEP"), SUM("DUAC"), SUM("DL"), SUM("VN"), SUM("CTC"), SUM("Autres"), SUM("TOTAL")
  FROM detail
) t
ORDER BY (exercice = 'TOTAL'), exercice;
