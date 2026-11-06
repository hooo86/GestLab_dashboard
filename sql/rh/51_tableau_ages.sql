-- Tableau des âges : effectifs par tranche, hommes / femmes / autre, % et âge moyen
-- Âge calculé à la date d'arrêté (sans valeur : aujourd'hui).
-- Visualisation : Tableau. Dernière ligne : TOTAL
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}   Date
--   {{departement}}   Filtre de champ → Hr Department → Name
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
employes AS (
  SELECT
    hr_employee.gender,
    CASE WHEN hr_employee.birthday IS NULL THEN NULL
         ELSE date_part('year', age(parametres.date_arrete, hr_employee.birthday))::int END AS age
  FROM hr_employee
  CROSS JOIN parametres
  LEFT JOIN hr_department ON hr_department.id = hr_employee.department_id
  WHERE hr_employee.active
    [[AND {{departement}}]]
),
tranches AS (
  SELECT
    CASE WHEN age IS NULL THEN 99 WHEN age < 20 THEN 0 WHEN age >= 65 THEN 10
         ELSE (age - 20) / 5 + 1 END AS ordre,
    CASE WHEN age IS NULL THEN 'Non renseigné'
         WHEN age < 20     THEN 'Moins de 20 ans'
         WHEN age >= 65    THEN '65 ans et plus'
         ELSE (20 + (age - 20) / 5 * 5)::text || '-' || (24 + (age - 20) / 5 * 5)::text || ' ans' END AS tranche,
    gender,
    age
  FROM employes
),
detail AS (
  SELECT
    ordre,
    tranche,
    COUNT(*) FILTER (WHERE gender = 'male')                      AS hommes,
    COUNT(*) FILTER (WHERE gender = 'female')                    AS femmes,
    COUNT(*) FILTER (WHERE gender IS NULL OR gender NOT IN ('male', 'female')) AS autre_ou_non_renseigne,
    COUNT(*)                                                     AS total,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 1) AS part_pct,
    ROUND(AVG(age), 1)                                           AS age_moyen
  FROM tranches
  GROUP BY ordre, tranche
)
SELECT tranche, hommes, femmes, autre_ou_non_renseigne, total, part_pct, age_moyen
FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 1000, 'TOTAL', SUM(hommes), SUM(femmes), SUM(autre_ou_non_renseigne), SUM(total),
         100.0, (SELECT ROUND(AVG(age), 1) FROM tranches)
  FROM detail
) t
ORDER BY ordre;
