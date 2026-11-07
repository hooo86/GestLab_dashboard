-- Devis non encore confirmés (pipeline commercial)
-- Affichage conseillé : nombre + montant total, ou tableau
-- Filtre Metabase : {{unite}} (Filtre de champ → Operating Unit → Name, facultatif) : unité de la commande
SELECT
  so.name             AS devis,
  p.name              AS client,
  so.date_order::date AS date_devis,
  so.validity_date    AS valable_jusqu_au,
  so.amount_untaxed   AS montant_ht
FROM sale_order so
LEFT JOIN operating_unit ON operating_unit.id = so.operating_unit_id
LEFT JOIN res_partner p ON p.id = so.partner_id
WHERE so.state IN ('draft', 'sent')
  AND TRUE /* perimetre:so */  -- unités de l'utilisateur (remplacé par le script de copie)
  [[AND {{unite}}]]
ORDER BY so.date_order DESC
