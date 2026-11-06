-- Encaissements par mois (paiements lettrés avec une facture client)
-- Date retenue : date du paiement ; si le paiement est antérieur à la facture,
-- date de la facture.
-- Visualisation : Barres (X = mois, Y = montant_encaisse)
-- Filtres Metabase : {{annee}} (Nombre, défaut 2026),
--                    {{unite}} (Filtre de champ → Operating Unit → Name)
-- Sans aucun filtre (année ni dates) : année en cours.
-- Période d'encaissement :
--   {{date_debut}} / {{date_fin}}  Date : période d'encaissement (du … au …), facultatives
-- Filtre DR : {{dr}} (Texte, facultatif) = nom de la direction régionale
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
    -- Direction régionale de l'unité de la facture (l'unité elle-même si c'est une DR)
    [[AND EXISTS (SELECT 1 FROM operating_unit u_dr JOIN operating_unit d_dr ON d_dr.id = CASE WHEN COALESCE(u_dr.is_dr, false) THEN u_dr.id ELSE u_dr.parent_dr_id END WHERE u_dr.id = account_move.operating_unit_id AND d_dr.name = {{dr}})]]
    -- Filtre sur la date d'encaissement (date du paiement, ou de la facture si antérieure)
    [[AND GREATEST(pay.date, account_move.invoice_date) >= {{date_debut}}]]
    [[AND GREATEST(pay.date, account_move.invoice_date) <= {{date_fin}}]]
    [[AND {{unite}}]]
)
SELECT
  to_char(date_encaissement, 'YYYY-MM') AS mois,
  COUNT(DISTINCT facture_id)            AS nb_factures,
  SUM(montant)                          AS montant_encaisse
FROM encaissements
WHERE 1 = 1
    [[AND EXTRACT(YEAR FROM date_encaissement) = {{annee}}]]
    -- sans aucun filtre (année ni dates) : année en cours
    AND (EXTRACT(YEAR FROM date_encaissement) = EXTRACT(YEAR FROM CURRENT_DATE)
      [[OR {{annee}} IS NOT NULL]] [[OR {{date_debut}} IS NOT NULL]] [[OR {{date_fin}} IS NOT NULL]])
GROUP BY 1
ORDER BY 1;
