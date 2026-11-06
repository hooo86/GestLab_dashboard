-- 10 meilleurs clients de chaque unité opérationnelle (CA HT)
-- Visualisation : Tableau (ou Barres horizontales avec un filtre {{unite}})
-- Filtres Metabase : {{annee}} et {{unite}}
SELECT unite, rang, client, ca_ht
FROM (
  SELECT
    COALESCE(operating_unit.name, 'Sans unité') AS unite,
    COALESCE(p.name, 'Sans client')             AS client,
    SUM(account_move.amount_untaxed_signed)     AS ca_ht,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(operating_unit.name, 'Sans unité')
      ORDER BY SUM(account_move.amount_untaxed_signed) DESC
    ) AS rang
  FROM account_move
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  LEFT JOIN res_partner p  ON p.id = account_move.commercial_partner_id
  WHERE account_move.move_type IN ('out_invoice', 'out_refund')
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{annee}}]]
    [[AND {{unite}}]]
  GROUP BY 1, 2
) t
WHERE rang <= 10
ORDER BY unite, rang;
