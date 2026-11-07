-- Commandes confirmées HT par commercial et par mois (module Ventes)
-- Graphique conseillé : barres empilées
-- Filtre Metabase : {{unite}} (Filtre de champ → Operating Unit → Name, facultatif) : unité de la commande
SELECT
  to_char(so.date_order, 'YYYY-MM') AS mois,
  COALESCE(up.name, 'Sans commercial')     AS commercial,
  SUM(so.amount_untaxed)                   AS ventes_ht
FROM sale_order so
LEFT JOIN operating_unit ON operating_unit.id = so.operating_unit_id
LEFT JOIN res_users u    ON u.id = so.user_id
LEFT JOIN res_partner up ON up.id = u.partner_id
WHERE so.state IN ('sale', 'done')  -- 'done' n'existe plus depuis Odoo 17, sans effet
  AND TRUE /* perimetre:so */  -- unités de l'utilisateur (remplacé par le script de copie)
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY 1, 3 DESC
