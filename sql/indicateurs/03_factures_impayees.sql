-- Factures clients non payées, avec le nombre de jours de retard
-- Affichage conseillé : tableau
SELECT
  m.name                                    AS facture,
  p.name                                    AS client,
  m.invoice_date                            AS date_facture,
  m.invoice_date_due                        AS echeance,
  m.amount_total                            AS montant_ttc,
  m.amount_residual                         AS reste_a_payer,
  GREATEST(CURRENT_DATE - m.invoice_date_due, 0) AS jours_de_retard
FROM account_move m
LEFT JOIN res_partner p ON p.id = m.commercial_partner_id
WHERE m.move_type = 'out_invoice'
  AND m.state = 'posted'
  AND m.commercial_partner_id IS DISTINCT FROM 1005  -- client interne exclu
  AND m.payment_state IN ('not_paid', 'partial')
ORDER BY jours_de_retard DESC, reste_a_payer DESC;
