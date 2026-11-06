-- Balance des créances clients en fin de mois
-- Créance d'une facture = montant TTC de la facture, diminué de ce qui a été
-- lettré dessus (encaissement, avoir, autre) À LA DATE D'EFFET :
--   date d'effet = date du règlement si elle est après la date de facture,
--                  sinon date de la facture.
-- Exemples :
--   facture d'avril payée en mai           → créance fin avril, soldée fin mai
--   facture d'avril annulée par avoir en mai → créance fin avril, soldée fin mai
-- Les paiements et avoirs non lettrés ne diminuent pas les créances.
--
-- Colonnes : créances début de mois + facturé − encaissé − avoirs − autres = créances fin de mois
-- Visualisation : Tableau, ou Barres/Lignes (X = mois, Y = creances_fin_mois)
-- Filtres Metabase (facultatifs) :
--   {{annee}}      Nombre (défaut 2026 ; sans valeur : année en cours)
--   {{categorie}}  Texte (classe client)
--   {{unite}}      Filtre de champ → Operating Unit → Name
WITH factures AS (
  SELECT
    account_move.id,
    account_move.invoice_date,
    account_move.amount_total_signed AS montant
  FROM account_move
  LEFT JOIN operating_unit ON operating_unit.id = account_move.operating_unit_id
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
    AND NOT EXISTS (  -- famille client « client interne » (id 1005) exclue
      SELECT 1 FROM res_partner x
      WHERE x.id = account_move.commercial_partner_id AND x.family_customer = 1005)
    [[AND cat.categorie = {{categorie}}]]
    [[AND {{unite}}]]
),
reglements AS (
  -- Tout ce qui a été lettré sur la ligne client de la facture
  SELECT
    GREATEST(cp.date, f.invoice_date) AS date_effet,
    CASE WHEN cp_move.move_type = 'out_refund'  THEN 'avoir'
         WHEN j.type IN ('bank', 'cash')        THEN 'encaissement'
         ELSE 'autre' END              AS nature,
    apr.amount                        AS montant
  FROM account_partial_reconcile apr
  JOIN account_move_line inv     ON inv.id = apr.debit_move_id
  JOIN factures f                ON f.id = inv.move_id
  JOIN account_move_line cp      ON cp.id = apr.credit_move_id     -- contrepartie
  JOIN account_move      cp_move ON cp_move.id = cp.move_id
  JOIN account_journal   j       ON j.id = cp.journal_id
  WHERE cp.parent_state = 'posted'
),
mois AS (
  SELECT d::date AS debut,
         (d + INTERVAL '1 month - 1 day')::date AS fin
  FROM generate_series(
         make_date(COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))::int, 1, 1),
         LEAST(make_date(COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))::int, 12, 1),
               date_trunc('month', CURRENT_DATE)::date),
         INTERVAL '1 month') AS d
)
SELECT
  to_char(m.debut, 'YYYY-MM') AS mois,
  COALESCE((SELECT SUM(f.montant) FROM factures f WHERE f.invoice_date < m.debut), 0)
  - COALESCE((SELECT SUM(r.montant) FROM reglements r WHERE r.date_effet < m.debut), 0)
                                                                         AS creances_debut_mois,
  COALESCE((SELECT SUM(f.montant) FROM factures f
            WHERE f.invoice_date BETWEEN m.debut AND m.fin), 0)          AS facture_mois,
  COALESCE((SELECT SUM(r.montant) FROM reglements r WHERE r.nature = 'encaissement'
            AND r.date_effet BETWEEN m.debut AND m.fin), 0)              AS encaisse_mois,
  COALESCE((SELECT SUM(r.montant) FROM reglements r WHERE r.nature = 'avoir'
            AND r.date_effet BETWEEN m.debut AND m.fin), 0)              AS avoirs_mois,
  COALESCE((SELECT SUM(r.montant) FROM reglements r WHERE r.nature = 'autre'
            AND r.date_effet BETWEEN m.debut AND m.fin), 0)              AS autres_reglements_mois,
  COALESCE((SELECT SUM(f.montant) FROM factures f WHERE f.invoice_date <= m.fin), 0)
  - COALESCE((SELECT SUM(r.montant) FROM reglements r WHERE r.date_effet <= m.fin), 0)
                                                                         AS creances_fin_mois
FROM mois m
ORDER BY m.debut;
