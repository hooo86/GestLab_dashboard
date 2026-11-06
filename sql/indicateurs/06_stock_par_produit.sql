-- Quantités en stock par produit (emplacements internes uniquement)
-- Affichage conseillé : tableau
-- Odoo 16+ : le nom du produit est traduit (format JSON) ; changez 'fr_FR' si besoin.
SELECT
  COALESCE(pt.name->>'fr_FR', pt.name->>'en_US') AS produit,
  pp.default_code                                AS reference,
  SUM(q.quantity)                                AS quantite_en_stock,
  SUM(q.reserved_quantity)                       AS quantite_reservee
FROM stock_quant q
JOIN stock_location l     ON l.id = q.location_id AND l.usage = 'internal'
JOIN product_product pp   ON pp.id = q.product_id
JOIN product_template pt  ON pt.id = pp.product_tmpl_id
GROUP BY 1, 2
ORDER BY quantite_en_stock DESC;
