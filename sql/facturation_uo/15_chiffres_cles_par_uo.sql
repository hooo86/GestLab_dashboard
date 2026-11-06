-- Chiffres clés par unité opérationnelle : CA du mois, CA de l'année,
-- nombre de factures du mois, reste à encaisser
-- Visualisation : Tableau ; ou une carte « Nombre » par colonne avec le filtre {{unite}}
-- Filtre Metabase : {{unite}}
SELECT
  COALESCE(operating_unit.name, 'Sans unité') AS unite,
  SUM(account_move.amount_untaxed_signed) FILTER (
    WHERE account_move.invoice_date >= date_trunc('month', CURRENT_DATE)) AS ca_mois,
  SUM(account_move.amount_untaxed_signed) FILTER (
    WHERE account_move.invoice_date >= date_trunc('year', CURRENT_DATE))  AS ca_annee,
  COUNT(*) FILTER (
    WHERE account_move.move_type = 'out_invoice'
      AND account_move.invoice_date >= date_trunc('month', CURRENT_DATE)) AS nb_factures_mois,
  SUM(account_move.amount_residual) FILTER (
    WHERE account_move.move_type = 'out_invoice'
      AND account_move.payment_state IN ('not_paid', 'partial'))          AS reste_a_encaisser
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  AND account_move.commercial_partner_id IS DISTINCT FROM 1005  -- client interne exclu
  [[AND {{unite}}]]
GROUP BY 1
ORDER BY ca_annee DESC NULLS LAST;
