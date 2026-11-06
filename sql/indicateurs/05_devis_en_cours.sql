-- Devis non encore confirmés (pipeline commercial)
-- Affichage conseillé : nombre + montant total, ou tableau
SELECT
  so.name             AS devis,
  p.name              AS client,
  so.date_order::date AS date_devis,
  so.validity_date    AS valable_jusqu_au,
  so.amount_untaxed   AS montant_ht
FROM sale_order so
LEFT JOIN res_partner p ON p.id = so.partner_id
WHERE so.state IN ('draft', 'sent')
ORDER BY so.date_order DESC;
