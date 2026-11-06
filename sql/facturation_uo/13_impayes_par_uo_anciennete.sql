-- Reste à encaisser par unité opérationnelle, par ancienneté du retard
-- Visualisation : Barres empilées (X = unite, Y = les 5 colonnes de montants)
--                 ou Tableau
-- Filtre Metabase : {{unite}}
SELECT
  COALESCE(operating_unit.name, 'Sans unité') AS unite,
  SUM(account_move.amount_residual) FILTER (
    WHERE account_move.invoice_date_due >= CURRENT_DATE)                        AS non_echu,
  SUM(account_move.amount_residual) FILTER (
    WHERE CURRENT_DATE - account_move.invoice_date_due BETWEEN 1 AND 30)        AS retard_1_30_j,
  SUM(account_move.amount_residual) FILTER (
    WHERE CURRENT_DATE - account_move.invoice_date_due BETWEEN 31 AND 60)       AS retard_31_60_j,
  SUM(account_move.amount_residual) FILTER (
    WHERE CURRENT_DATE - account_move.invoice_date_due BETWEEN 61 AND 90)       AS retard_61_90_j,
  SUM(account_move.amount_residual) FILTER (
    WHERE CURRENT_DATE - account_move.invoice_date_due > 90)                    AS retard_plus_90_j,
  SUM(account_move.amount_residual)                                             AS total_a_encaisser
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type = 'out_invoice'
  AND account_move.state = 'posted'
  AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
  AND account_move.payment_state IN ('not_paid', 'partial')
  [[AND {{unite}}]]
GROUP BY 1
ORDER BY total_a_encaisser DESC;
