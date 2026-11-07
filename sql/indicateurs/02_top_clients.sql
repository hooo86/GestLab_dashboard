-- 10 meilleurs clients sur les 12 derniers mois (CA facturé HT)
-- Graphique conseillé : barres horizontales
-- Filtre Metabase : {{unite}} (Filtre de champ → Operating Unit → Name, facultatif)
SELECT
  COALESCE(p.name, 'Sans client')  AS client,
  SUM(m.amount_untaxed_signed)     AS ca_ht
FROM account_move m
LEFT JOIN operating_unit ON operating_unit.id = m.operating_unit_id
LEFT JOIN res_partner p ON p.id = m.commercial_partner_id
WHERE m.move_type IN ('out_invoice', 'out_refund')
  AND m.state = 'posted'
  AND m.journal_id = 1  -- journal « Factures clients » uniquement
  AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
    SELECT 1 FROM res_partner x
    WHERE x.id = m.commercial_partner_id AND x.family_customer = 1005)
  AND TRUE /* perimetre:m */  -- unités de l'utilisateur (remplacé par le script de copie)
  [[AND {{unite}}]]
  AND m.invoice_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY 1
ORDER BY ca_ht DESC
LIMIT 10;
