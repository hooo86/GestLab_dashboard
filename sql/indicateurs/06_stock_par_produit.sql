-- Quantités en stock par produit (emplacements internes uniquement)
-- Affichage conseillé : tableau
-- Odoo 16+ : le nom du produit est traduit (format JSON) ; changez 'fr_FR' si besoin.
-- Filtre Metabase : {{unite}} (Filtre de champ → Operating Unit → Name, facultatif) : unité de l'emplacement
SELECT
  COALESCE(pt.name->>'fr_FR', pt.name->>'en_US') AS produit,
  pp.default_code                                AS reference,
  SUM(q.quantity)                                AS quantite_en_stock,
  SUM(q.reserved_quantity)                       AS quantite_reservee
FROM stock_quant q
JOIN stock_location l     ON l.id = q.location_id AND l.usage = 'internal'
LEFT JOIN stock_warehouse wh ON wh.id = l.warehouse_id
LEFT JOIN LATERAL (SELECT COALESCE((to_jsonb(l) ->> 'operating_unit_id')::int, (to_jsonb(wh) ->> 'operating_unit_id')::int) AS id) unite_stock ON true
LEFT JOIN operating_unit ON operating_unit.id = unite_stock.id
JOIN product_product pp   ON pp.id = q.product_id
JOIN product_template pt  ON pt.id = pp.product_tmpl_id
WHERE TRUE
  AND TRUE /* perimetre:unite_stock.id */  -- unités de l'utilisateur (remplacé par le script de copie)
  [[AND {{unite}}]]
GROUP BY 1, 2
ORDER BY quantite_en_stock DESC
