-- Départs à la retraite prévus : employés présents à la date d'arrêté, par année
-- où ils atteignent l'âge de la retraite, sur les 10 années suivantes. Dernière ligne : TOTAL
-- Visualisation : Barres (X = annee, séries = hommes et femmes) ; Tableau avec la ligne TOTAL
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}   Date (sans valeur : aujourd'hui)
--   {{age_retraite}}  Nombre (sans valeur : 60)
--   {{departement}}   Filtre de champ → Hr Department → Name
--   {{unite}}         Filtre de champ → Operating Unit → Name (unité de l'employé)
WITH parametres AS (
  SELECT COALESCE([[{{date_arrete}}::date, ]] CURRENT_DATE) AS date_arrete
),
employes AS (
  SELECT
    hr_employee.id,
    hr_employee.name                                       AS nom,
    hr_employee.gender,
    hr_employee.birthday,
    hr_employee.date_ru,
    COALESCE(CASE WHEN jsonb_typeof(to_jsonb(operating_unit.name)) = 'object' THEN COALESCE(to_jsonb(operating_unit.name)->>'fr_FR', to_jsonb(operating_unit.name)->>'en_US') ELSE to_jsonb(operating_unit.name)#>>'{}' END, 'Sans unité')   AS unite,
    COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_department.name)) = 'object' THEN COALESCE(to_jsonb(hr_department.name)->>'fr_FR', to_jsonb(hr_department.name)->>'en_US') ELSE to_jsonb(hr_department.name)#>>'{}' END, 'Sans département') AS departement,
    COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_job.name)) = 'object' THEN COALESCE(to_jsonb(hr_job.name)->>'fr_FR', to_jsonb(hr_job.name)->>'en_US') ELSE to_jsonb(hr_job.name)#>>'{}' END, NULLIF(hr_employee.job_title, ''), 'Non renseigné') AS poste,
    CASE WHEN hr_employee.birthday IS NULL THEN NULL
         ELSE date_part('year', age(parametres.date_arrete, hr_employee.birthday))::int END AS age,
    CASE WHEN hr_employee.date_ru IS NULL THEN NULL
         ELSE date_part('year', age(parametres.date_arrete, hr_employee.date_ru))::int END AS anciennete
  FROM hr_employee
  LEFT JOIN hr_department  ON hr_department.id  = hr_employee.department_id
  LEFT JOIN operating_unit ON operating_unit.id = hr_employee.default_operating_unit_id
  LEFT JOIN hr_job         ON hr_job.id         = hr_employee.job_id
  CROSS JOIN parametres
  WHERE (hr_employee.date_ru IS NULL OR hr_employee.date_ru <= parametres.date_arrete)
    AND (hr_employee.departure_date > parametres.date_arrete
         OR (hr_employee.departure_date IS NULL AND hr_employee.active))
    AND hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
    AND TRUE /* perimetre:hr_employee.default_operating_unit_id */  -- unités de l'utilisateur (remplacé par le script de copie)
    [[AND {{departement}}]]
    [[AND {{unite}}]]
),
retraites AS (
  SELECT e.*,
         EXTRACT(YEAR FROM e.birthday)::int + COALESCE([[{{age_retraite}}, ]] 60) AS annee_retraite
  FROM employes e
  WHERE e.birthday IS NOT NULL
),
detail AS (
  SELECT
    annee_retraite::text                       AS annee,
    annee_retraite                             AS ordre,
    COUNT(*) FILTER (WHERE gender = 'male')    AS hommes,
    COUNT(*) FILTER (WHERE gender = 'female')  AS femmes,
    COUNT(*)                                   AS total
  FROM retraites, parametres
  WHERE annee_retraite BETWEEN EXTRACT(YEAR FROM parametres.date_arrete)
                           AND EXTRACT(YEAR FROM parametres.date_arrete) + 10
  GROUP BY annee_retraite
)
SELECT annee, hommes, femmes, total FROM (
  SELECT * FROM detail
  UNION ALL
  SELECT 'TOTAL', 99999, SUM(hommes), SUM(femmes), SUM(total) FROM detail
) t
ORDER BY ordre
