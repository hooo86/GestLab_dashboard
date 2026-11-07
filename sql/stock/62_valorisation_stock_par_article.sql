-- Valorisation du stock par ARTICLE (avec sa famille) sur une période
-- Valeur de départ = mouvements avant le début de la période ;
-- entrées = mouvements de la période qui ajoutent du stock (quantité > 0) ;
-- sorties = mouvements de la période qui retirent du stock (quantité < 0), en valeur positive ;
-- valeur finale = départ + entrées − sorties = valeur du stock à la fin de la période.
-- Les réévaluations (quantité 0) vont en entrée ou en sortie selon leur signe.
-- Catégories d'investissement (is_categorie_investissement = 1) exclues. Dates en heure d'Algérie. Source : stock_valuation_layer (valorisation Odoo).
-- Visualisation : Tableau. Dernière ligne : TOTAL
-- Filtres Metabase (facultatifs) :
--   {{date_debut}} / {{date_fin}}  Date : période (sans valeur : du 1er janvier à aujourd'hui)
--   {{famille}}    Filtre de champ → Product Category → Complete Name (choix multiple)
WITH parametres AS (
  SELECT COALESCE([[{{date_debut}}::date, ]] date_trunc('year', CURRENT_DATE)::date) AS debut,
         COALESCE([[{{date_fin}}::date, ]] CURRENT_DATE)                            AS fin
),
mouvements AS (
  -- Une ligne par mouvement de stock valorisé (couche de valorisation Odoo)
  SELECT
    COALESCE(product_category.complete_name, CASE WHEN jsonb_typeof(to_jsonb(product_category.name)) = 'object' THEN COALESCE(to_jsonb(product_category.name)->>'fr_FR', to_jsonb(product_category.name)->>'en_US') ELSE to_jsonb(product_category.name)#>>'{}' END, 'Sans famille') AS famille,
    COALESCE(product_product.default_code || ' - ', '') || COALESCE(CASE WHEN jsonb_typeof(to_jsonb(product_template.name)) = 'object' THEN COALESCE(to_jsonb(product_template.name)->>'fr_FR', to_jsonb(product_template.name)->>'en_US') ELSE to_jsonb(product_template.name)#>>'{}' END, '?') AS article,
    (stock_valuation_layer.create_date AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Algiers')::date AS jour,
    stock_valuation_layer.quantity,
    stock_valuation_layer.value
  FROM stock_valuation_layer
  JOIN product_product        ON product_product.id  = stock_valuation_layer.product_id
  JOIN product_template       ON product_template.id = product_product.product_tmpl_id
  LEFT JOIN product_category  ON product_category.id = product_template.categ_id
  CROSS JOIN parametres
  WHERE (stock_valuation_layer.create_date AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Algiers')::date <= parametres.fin
    -- Catégories d'investissement exclues (is_categorie_investissement = 1)
    AND COALESCE(product_category.is_categorie_investissement::int, 0) <> 1
    [[AND {{famille}}]]
),
detail AS (
  SELECT
    m.famille,
    m.article,
    COALESCE(SUM(m.value) FILTER (WHERE m.jour < p.debut), 0)                                     AS valeur_depart,
    COALESCE(SUM(m.value) FILTER (WHERE m.jour >= p.debut
               AND (m.quantity > 0 OR (m.quantity = 0 AND m.value > 0))), 0)                       AS valeur_entrees,
    COALESCE(-SUM(m.value) FILTER (WHERE m.jour >= p.debut
               AND (m.quantity < 0 OR (m.quantity = 0 AND m.value < 0))), 0)                       AS valeur_sorties,
    COALESCE(SUM(m.value), 0)                                                                    AS valeur_finale
  FROM mouvements m CROSS JOIN parametres p
  GROUP BY m.famille, m.article
)
SELECT * FROM (
  SELECT * FROM detail
  WHERE valeur_depart <> 0 OR valeur_entrees <> 0 OR valeur_sorties <> 0 OR valeur_finale <> 0
  UNION ALL
  SELECT 'TOTAL', '', SUM(valeur_depart), SUM(valeur_entrees), SUM(valeur_sorties), SUM(valeur_finale)
  FROM detail
) t
ORDER BY (famille = 'TOTAL'), famille, article
