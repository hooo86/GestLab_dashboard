-- CA HT depuis le 1er janvier, comparé à la même période de l'an dernier
-- Visualisation : Tableau (mise en forme : evolution_pct en vert/rouge)
--                 ou Barres groupées (X = unite, Y = ca_n et ca_n1)
-- Filtre Metabase : {{unite}} (pas de filtre de période : elle est calculée)
-- Dernière ligne : TOTAL
WITH detail AS (
  SELECT
    COALESCE(operating_unit.name, 'Sans unité') AS unite,
    SUM(account_move.amount_untaxed_signed) FILTER (
      WHERE account_move.invoice_date >= date_trunc('year', CURRENT_DATE)
    ) AS ca_n,
    SUM(account_move.amount_untaxed_signed) FILTER (
      WHERE account_move.invoice_date <  date_trunc('year', CURRENT_DATE)
        AND account_move.invoice_date <= CURRENT_DATE - INTERVAL '1 year'
    ) AS ca_n1,
    ROUND(100.0 * (
        SUM(account_move.amount_untaxed_signed) FILTER (
          WHERE account_move.invoice_date >= date_trunc('year', CURRENT_DATE))
      - SUM(account_move.amount_untaxed_signed) FILTER (
          WHERE account_move.invoice_date <  date_trunc('year', CURRENT_DATE)
            AND account_move.invoice_date <= CURRENT_DATE - INTERVAL '1 year')
    ) / NULLIF(SUM(account_move.amount_untaxed_signed) FILTER (
          WHERE account_move.invoice_date <  date_trunc('year', CURRENT_DATE)
            AND account_move.invoice_date <= CURRENT_DATE - INTERVAL '1 year'), 0), 1) AS evolution_pct
  FROM account_move
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  WHERE account_move.move_type IN ('out_invoice', 'out_refund')
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    AND account_move.invoice_date >= date_trunc('year', CURRENT_DATE) - INTERVAL '1 year'
    [[AND {{unite}}]]
  GROUP BY 1
)
SELECT * FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM(ca_n), SUM(ca_n1), ROUND(100.0 * (SUM(ca_n) - SUM(ca_n1)) / NULLIF(SUM(ca_n1), 0), 1)
  FROM detail
) t
ORDER BY (unite = 'TOTAL'), ca_n DESC NULLS LAST;
