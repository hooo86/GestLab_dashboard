-- Chiffre d'affaires facturé HT par mois (factures clients validées, avoirs déduits)
-- Graphique conseillé : barres
SELECT
  date_trunc('month', m.invoice_date)::date AS mois,
  SUM(m.amount_untaxed_signed)              AS ca_ht
FROM account_move m
WHERE m.move_type IN ('out_invoice', 'out_refund')
  AND m.state = 'posted'
GROUP BY 1
ORDER BY 1;
