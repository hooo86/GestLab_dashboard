-- Pyramide des âges : employés actifs par tranche de 5 ans, hommes / femmes
-- Âge calculé à la date d'arrêté (sans valeur : aujourd'hui), d'après la date de naissance.
-- Visualisation : Barres horizontales (« Rangée »), empilées
--   axe = tranche, séries = hommes (valeurs négatives → à gauche) et femmes (à droite)
--   ⚙️ Affichage : « Empiler » ; colonne hommes → format sans signe (voir README)
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
-- Toutes les tranches, même vides, pour une pyramide sans trou
toutes AS (
  SELECT o AS ordre,
         CASE WHEN o = 0  THEN 'Moins de 20 ans'
              WHEN o = 10 THEN '65 ans et plus'
              ELSE (20 + (o - 1) * 5)::text || '-' || (24 + (o - 1) * 5)::text || ' ans' END AS tranche
  FROM generate_series(0, 10) AS o
)
SELECT
  toutes.tranche,
  -COUNT(t.ordre) FILTER (WHERE t.gender = 'male')   AS hommes,
  COUNT(t.ordre)  FILTER (WHERE t.gender = 'female') AS femmes
FROM toutes
LEFT JOIN tranches t ON t.ordre = toutes.ordre   -- sans date de naissance : voir la requête 51
GROUP BY toutes.ordre, toutes.tranche
ORDER BY toutes.ordre DESC;                      -- les plus âgés en haut
