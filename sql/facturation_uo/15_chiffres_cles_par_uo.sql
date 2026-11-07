-- Chiffres clés par unité opérationnelle, à une date d'arrêté :
-- CA HT du mois et de l'année (jusqu'à la date), nombre de factures du mois,
-- reste à encaisser TTC à la date (règlements lettrés à leur date d'effet).
-- Visualisation : Tableau ; ou une carte « Nombre » par colonne avec le filtre {{unite}}
-- Filtres Metabase : {{date_arrete}} (Date ; sans valeur : aujourd'hui),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Dernière ligne : TOTAL
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
pieces AS (
  SELECT
    account_move.id,
    account_move.move_type,
    COALESCE(operating_unit.name, 'Sans unité') AS unite,
    account_move.invoice_date,
    account_move.amount_untaxed_signed AS montant_ht,
    account_move.amount_total_signed   AS montant_ttc
  FROM account_move
  CROSS JOIN parametres
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
  WHERE account_move.move_type IN ('out_invoice', 'out_refund')
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    AND TRUE /* perimetre:account_move */  -- unités de l'utilisateur (remplacé par le script de copie)
    AND account_move.invoice_date <= parametres.date_arrete
    [[AND {{unite}}]]
),
reglements AS (
  SELECT inv.move_id AS facture_id, SUM(apr.amount) AS montant
  FROM account_partial_reconcile apr
  JOIN account_move_line inv ON inv.id = apr.debit_move_id
  JOIN pieces f              ON f.id = inv.move_id AND f.move_type = 'out_invoice'
  JOIN account_move_line cp  ON cp.id = apr.credit_move_id
  CROSS JOIN parametres
  WHERE cp.parent_state = 'posted'
    AND GREATEST(cp.date, f.invoice_date) <= parametres.date_arrete
  GROUP BY inv.move_id
),
detail AS (
  SELECT
    f.unite,
    SUM(f.montant_ht) FILTER (
      WHERE f.invoice_date >= date_trunc('month', parametres.date_arrete)) AS ca_mois,
    SUM(f.montant_ht) FILTER (
      WHERE f.invoice_date >= date_trunc('year', parametres.date_arrete))  AS ca_annee,
    COUNT(*) FILTER (
      WHERE f.move_type = 'out_invoice'
        AND f.invoice_date >= date_trunc('month', parametres.date_arrete)) AS nb_factures_mois,
    SUM(f.montant_ttc - COALESCE(r.montant, 0)) FILTER (
      WHERE f.move_type = 'out_invoice')                                   AS reste_a_encaisser
  FROM pieces f
  CROSS JOIN parametres
  LEFT JOIN reglements r ON r.facture_id = f.id
  GROUP BY f.unite
)
SELECT * FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM(ca_mois), SUM(ca_annee), SUM(nb_factures_mois), SUM(reste_a_encaisser)
  FROM detail
) t
ORDER BY (unite = 'TOTAL'), ca_annee DESC NULLS LAST;
