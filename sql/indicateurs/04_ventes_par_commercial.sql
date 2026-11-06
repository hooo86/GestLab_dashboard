-- Commandes confirmées HT par commercial et par mois (module Ventes)
-- Graphique conseillé : barres empilées
SELECT
  date_trunc('month', so.date_order)::date AS mois,
  COALESCE(up.name, 'Sans commercial')     AS commercial,
  SUM(so.amount_untaxed)                   AS ventes_ht
FROM sale_order so
LEFT JOIN res_users u    ON u.id = so.user_id
LEFT JOIN res_partner up ON up.id = u.partner_id
WHERE so.state IN ('sale', 'done')  -- 'done' n'existe plus depuis Odoo 17, sans effet
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
