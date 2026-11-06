-- 10 meilleurs clients de chaque unité opérationnelle (CA HT)
-- Visualisation : Tableau (ou Barres horizontales avec un filtre {{unite}})
-- Filtres Metabase : {{periode}} et {{unite}}
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
    [[AND {{periode}}]]
    [[AND {{unite}}]]
  GROUP BY 1, 2
) t
WHERE rang <= 10
ORDER BY unite, rang;
