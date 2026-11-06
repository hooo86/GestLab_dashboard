-- Effectif total à la date d'arrêté (mêmes règles que 50 et 51)
-- type « Employé », recrutés (date_ru) au plus tard à la date,
-- partis (departure_date) après la date ou pas partis.
-- Visualisation : Nombre (affiche la 1re colonne : effectif_total),
--   ou Tableau pour voir hommes / femmes / âge moyen
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
  WHERE hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
    -- Recruté au plus tard à la date d'arrêté (date de recrutement inconnue : compté)
    AND (hr_employee.date_ru IS NULL OR hr_employee.date_ru <= parametres.date_arrete)
    -- Encore présent à la date d'arrêté :
    --   parti après cette date (même archivé aujourd'hui), ou pas de date de départ et fiche active
    AND (hr_employee.departure_date > parametres.date_arrete
         OR (hr_employee.departure_date IS NULL AND hr_employee.active))
    [[AND {{departement}}]]
)
SELECT
  COUNT(*)                                   AS effectif_total,
  COUNT(*) FILTER (WHERE gender = 'male')    AS hommes,
  COUNT(*) FILTER (WHERE gender = 'female')  AS femmes,
  ROUND(AVG(age), 1)                         AS age_moyen
FROM employes;
