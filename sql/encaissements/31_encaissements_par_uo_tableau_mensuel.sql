-- Tableau des encaissements : une ligne par unité, une colonne par mois, + total
-- Mêmes règles que 30 (paiements lettrés, date = max(date paiement, date facture)).
-- Visualisation : Tableau. Dernière ligne : TOTAL
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans aucun filtre (année ni dates) : année en cours.
-- Période d'encaissement :
--   {{date_debut}} / {{date_fin}}  Date : période d'encaissement (du … au …), facultatives
WITH encaissements AS (
  -- Une ligne = un lettrage entre une facture client et un paiement (banque / caisse).
  -- Les paiements non lettrés (montants en circulation) ne sont pas comptés.
  SELECT
    GREATEST(pay.date, account_move.invoice_date)  AS date_encaissement,
    account_move.id                                AS facture_id,
    COALESCE(operating_unit.name, 'Sans unité')    AS unite,
    apr.amount                                     AS montant
  FROM account_partial_reconcile apr
  JOIN account_move_line inv ON inv.id = apr.debit_move_id    -- ligne client de la facture
  JOIN account_move          ON account_move.id = inv.move_id
  JOIN account_move_line pay ON pay.id = apr.credit_move_id   -- ligne du paiement
  JOIN account_journal   j   ON j.id = pay.journal_id
  LEFT JOIN operating_unit   ON operating_unit.id = account_move.operating_unit_id
  WHERE account_move.move_type = 'out_invoice'
    AND account_move.state = 'posted'
    AND account_move.journal_id = 1  -- journal « Factures clients » uniquement
    AND pay.parent_state = 'posted'
    AND j.type IN ('bank', 'cash')   -- vrais encaissements (pas les avoirs ni les OD)
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    -- Filtre sur la date d'encaissement (date du paiement, ou de la facture si antérieure)
    [[AND GREATEST(pay.date, account_move.invoice_date) >= {{date_debut}}]]
    [[AND GREATEST(pay.date, account_move.invoice_date) <= {{date_fin}}]]
    [[AND {{unite}}]]
),
detail AS (
  SELECT
    unite,
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 1) AS "Janv.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 2) AS "Févr.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 3) AS "Mars",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 4) AS "Avr.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 5) AS "Mai",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 6) AS "Juin",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 7) AS "Juil.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 8) AS "Août",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 9) AS "Sept.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 10) AS "Oct.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 11) AS "Nov.",
    SUM(montant) FILTER (WHERE EXTRACT(MONTH FROM date_encaissement) = 12) AS "Déc.",
    SUM(montant) AS "Total"
  FROM encaissements
  WHERE 1 = 1
      [[AND EXTRACT(YEAR FROM date_encaissement) = {{annee}}]]
      -- sans aucun filtre (année ni dates) : année en cours
      AND (EXTRACT(YEAR FROM date_encaissement) = EXTRACT(YEAR FROM CURRENT_DATE)
        [[OR {{annee}} IS NOT NULL]] [[OR {{date_debut}} IS NOT NULL]] [[OR {{date_fin}} IS NOT NULL]])
  GROUP BY unite
)
SELECT * FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', SUM("Janv."), SUM("Févr."), SUM("Mars"), SUM("Avr."), SUM("Mai"), SUM("Juin"), SUM("Juil."), SUM("Août"), SUM("Sept."), SUM("Oct."), SUM("Nov."), SUM("Déc."), SUM("Total")
  FROM detail
) t
ORDER BY (unite = 'TOTAL'), "Total" DESC NULLS LAST;
