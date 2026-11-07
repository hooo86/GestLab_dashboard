-- Liste nominative des employés qui atteignent l'âge de la retraite dans les N prochaines années
-- (employés présents à la date d'arrêté)
-- Visualisation : Tableau
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}   Date (sans valeur : aujourd'hui)
--   {{age_retraite}}  Nombre (sans valeur : 60)
--   {{horizon}}       Nombre d'années (sans valeur : 5)
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
)
SELECT
  e.nom,
  e.unite,
  e.departement,
  e.poste,
  e.birthday                                                         AS date_naissance,
  e.age,
  (e.birthday + make_interval(years => COALESCE([[{{age_retraite}}, ]] 60)::int))::date AS date_retraite,
  e.date_ru                                                          AS date_recrutement,
  e.anciennete
FROM employes e, parametres
WHERE e.birthday IS NOT NULL
  AND e.birthday + make_interval(years => COALESCE([[{{age_retraite}}, ]] 60)::int)
      <= parametres.date_arrete + make_interval(years => COALESCE([[{{horizon}}, ]] 5)::int)
ORDER BY date_retraite
