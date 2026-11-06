-- CA HT par unité opérationnelle et par année (comparaison d'une année à l'autre)
-- Visualisation : Barres groupées (X = annee, Y = ca_ht, série = unite)
-- Filtres Metabase : {{annee}} et {{unite}}
SELECT
  EXTRACT(YEAR FROM account_move.invoice_date)::int AS annee,
  COALESCE(operating_unit.name, 'Sans unité')       AS unite,
  SUM(account_move.amount_untaxed_signed)            AS ca_ht
FROM account_move
LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
WHERE account_move.move_type IN ('out_invoice', 'out_refund')
  AND account_move.state = 'posted'
  [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
