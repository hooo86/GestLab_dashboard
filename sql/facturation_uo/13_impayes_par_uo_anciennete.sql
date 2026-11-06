-- Reste à encaisser par unité opérationnelle et par ancienneté du retard, à une date d'arrêté
-- Reste = TTC − règlements lettrés dont la date d'effet (date du règlement, ou date de
-- facture si antérieure) est au plus tard à la date d'arrêté. Retard compté à cette date.
-- Visualisation : Barres empilées (X = unite, Y = les 5 colonnes de montants) ou Tableau
-- Filtres Metabase : {{date_arrete}} (Date ; sans valeur : aujourd'hui),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
factures AS (
  SELECT
    account_move.id,
    COALESCE(operating_unit.name, 'Sans unité') AS unite,
    account_move.invoice_date,
    account_move.invoice_date_due,
    account_move.amount_total_signed AS montant_ttc
  FROM account_move
  CROSS JOIN parametres
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  WHERE account_move.move_type = 'out_invoice'
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    AND account_move.invoice_date <= parametres.date_arrete
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
restes AS (
  SELECT f.unite,
         f.montant_ttc - COALESCE(r.montant, 0)  AS reste,
         parametres.date_arrete - f.invoice_date_due AS retard
  FROM factures f
  CROSS JOIN parametres
  LEFT JOIN reglements r ON r.facture_id = f.id
  WHERE f.montant_ttc - COALESCE(r.montant, 0) <> 0
)
SELECT
  unite,
  SUM(reste) FILTER (WHERE retard <= 0)              AS non_echu,
  SUM(reste) FILTER (WHERE retard BETWEEN 1 AND 30)  AS retard_1_30_j,
  SUM(reste) FILTER (WHERE retard BETWEEN 31 AND 60) AS retard_31_60_j,
  SUM(reste) FILTER (WHERE retard BETWEEN 61 AND 90) AS retard_61_90_j,
  SUM(reste) FILTER (WHERE retard > 90)              AS retard_plus_90_j,
  SUM(reste)                                         AS total_a_encaisser
FROM restes
GROUP BY unite
ORDER BY total_a_encaisser DESC;
