-- Factures clients non soldées à une date d'arrêté, avec le nombre de jours de retard
-- Reste à payer = TTC − règlements lettrés (encaissements, avoirs…) dont la date d'effet
-- (date du règlement, ou date de facture si antérieure) est au plus tard à la date d'arrêté.
-- Affichage conseillé : tableau
-- Filtre Metabase : {{date_arrete}} (Date ; sans valeur : aujourd'hui)
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
factures AS (
  SELECT m.id, m.name, m.commercial_partner_id, m.invoice_date, m.invoice_date_due,
         m.amount_total_signed AS montant_ttc
  FROM account_move m
  CROSS JOIN parametres
  WHERE m.move_type = 'out_invoice'
    AND m.state = 'posted'
    AND m.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = m.commercial_partner_id AND x.family_customer = 1005)
    AND TRUE /* perimetre:m */  -- unités de l'utilisateur (remplacé par le script de copie)
    AND m.invoice_date <= parametres.date_arrete
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
)
SELECT
  f.name                                     AS facture,
  p.name                                     AS client,
  f.invoice_date                             AS date_facture,
  f.invoice_date_due                         AS echeance,
  f.montant_ttc,
  f.montant_ttc - COALESCE(r.montant, 0)     AS reste_a_payer,
  GREATEST(parametres.date_arrete - f.invoice_date_due, 0) AS jours_de_retard
FROM factures f
CROSS JOIN parametres
LEFT JOIN reglements r  ON r.facture_id = f.id
LEFT JOIN res_partner p ON p.id = f.commercial_partner_id
WHERE f.montant_ttc - COALESCE(r.montant, 0) > 0
ORDER BY jours_de_retard DESC, reste_a_payer DESC;
