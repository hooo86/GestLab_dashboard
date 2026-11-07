-- Tableau CA HT : une ligne par direction régionale, une colonne par mois, + total
-- Visualisation : Tableau (mise en forme conditionnelle en dégradé)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026) et {{dr}} (Texte), {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans filtre Année, la requête prend l'année en cours.
-- Dernière ligne : TOTAL
WITH detail AS (
  SELECT
    COALESCE(dr.name, 'Sans DR') AS direction_regionale,
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 1)  AS "Janv.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 2)  AS "Févr.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 3)  AS "Mars",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 4)  AS "Avr.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 5)  AS "Mai",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 6)  AS "Juin",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 7)  AS "Juil.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 8)  AS "Août",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 9)  AS "Sept.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 10) AS "Oct.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 11) AS "Nov.",
    SUM(account_move.amount_untaxed_signed) FILTER (WHERE EXTRACT(MONTH FROM account_move.invoice_date) = 12) AS "Déc.",
    SUM(account_move.amount_untaxed_signed) AS "Total"
  FROM account_move
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id   -- unité de la facture
  LEFT JOIN operating_unit dr ON dr.id =   -- sa DR : l'unité elle-même si c'est une DR, sinon sa DR parente
    CASE WHEN COALESCE(operating_unit.is_dr, false) THEN operating_unit.id ELSE operating_unit.parent_dr_id END
  WHERE account_move.move_type IN ('out_invoice', 'out_refund')
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
  AND TRUE /* perimetre:account_move */  -- unités de l'utilisateur (remplacé par le script de copie)
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    AND EXTRACT(YEAR FROM account_move.invoice_date) =
        COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
    [[AND dr.name = {{dr}}]]
    [[AND {{unite}}]]
  GROUP BY 1
)
SELECT * FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM("Janv."), SUM("Févr."), SUM("Mars"), SUM("Avr."), SUM("Mai"), SUM("Juin"), SUM("Juil."), SUM("Août"), SUM("Sept."), SUM("Oct."), SUM("Nov."), SUM("Déc."), SUM("Total")
  FROM detail
) t
ORDER BY (direction_regionale = 'TOTAL'), "Total" DESC NULLS LAST;
