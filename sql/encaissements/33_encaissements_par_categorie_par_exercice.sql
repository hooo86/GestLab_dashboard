-- Encaissements par classe client (family_customer) et par EXERCICE DE LA FACTURE
-- Exercice = année de la date de facturation (pas la date du paiement).
-- Seuls les paiements banque/caisse lettrés avec une facture client sont comptés.
-- Lignes : détail catégorie × exercice, puis « Total catégorie », puis TOTAL général.
-- Visualisation : Tableau
-- Filtres Metabase (tous facultatifs) :
--   {{exercice}}            Nombre : exercice de la facture (ex. 2024)
--   {{annee_encaissement}}  Nombre : année où l'argent est rentré
--                           (date du paiement, ou de la facture si le paiement est antérieur)
--   {{categorie}}           Texte
--   {{unite}}               Filtre de champ → Operating Unit → Name
WITH encaissements AS (
  SELECT
    cat.categorie                                     AS categorie,
    EXTRACT(YEAR FROM account_move.invoice_date)::int AS exercice,
    account_move.id                                   AS facture_id,
    apr.amount                                        AS montant
  FROM account_partial_reconcile apr
  JOIN account_move_line inv ON inv.id = apr.debit_move_id    -- ligne client de la facture
  JOIN account_move          ON account_move.id = inv.move_id
  JOIN account_move_line pay ON pay.id = apr.credit_move_id   -- ligne du paiement
  JOIN account_journal   j   ON j.id = pay.journal_id
  LEFT JOIN operating_unit   ON operating_unit.id = account_move.operating_unit_id
  -- Classe client : family_customer de la société cliente (nom traduisible ou non)
  LEFT JOIN res_partner p      ON p.id = account_move.commercial_partner_id
  LEFT JOIN family_customer fc ON fc.id = p.family_customer
  LEFT JOIN LATERAL (
    SELECT COALESCE(
      CASE WHEN jsonb_typeof(to_jsonb(fc.name)) = 'object'
           THEN COALESCE(to_jsonb(fc.name)->>'fr_FR', to_jsonb(fc.name)->>'en_US')
           ELSE to_jsonb(fc.name)#>>'{}' END,
      'Sans catégorie') AS categorie
  ) cat ON true
  WHERE account_move.move_type = 'out_invoice'
    AND account_move.state = 'posted'
    AND pay.parent_state = 'posted'
    AND j.type IN ('bank', 'cash')   -- vrais encaissements (pas les avoirs ni les OD)
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    [[AND EXTRACT(YEAR FROM account_move.invoice_date) = {{exercice}}]]
    [[AND EXTRACT(YEAR FROM GREATEST(pay.date, account_move.invoice_date)) = {{annee_encaissement}}]]
    [[AND cat.categorie = {{categorie}}]]
    [[AND {{unite}}]]
)
SELECT
  CASE WHEN GROUPING(categorie) = 1 THEN 'TOTAL' ELSE categorie END AS categorie,
  CASE WHEN GROUPING(categorie) = 1 THEN ''
       WHEN GROUPING(exercice)  = 1 THEN 'Total catégorie'
       ELSE 'Exercice ' || exercice::text END                                       AS exercice,
  COUNT(DISTINCT facture_id)                                         AS nb_factures,
  SUM(montant)                                                       AS montant_encaisse
FROM encaissements
GROUP BY GROUPING SETS ((categorie, exercice), (categorie), ())
ORDER BY GROUPING(categorie), encaissements.categorie, GROUPING(exercice), encaissements.exercice;
