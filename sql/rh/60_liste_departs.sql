-- Liste nominative des départs (sorties) : une ligne par employé parti, avec la date de départ
-- Départ = date de départ (departure_date) de la fiche employé, type « Employé » uniquement.
-- Visualisation : Tableau
-- Filtres Metabase (facultatifs) :
--   {{annee}}         Nombre : année de départ (sans aucun filtre : année en cours)
--   {{date_debut}} / {{date_fin}}  Date : période de départ (du … au …)
--   {{motif}}         Texte : motif du départ
--   {{departement}}   Filtre de champ → Hr Department → Name
--   {{unite}}         Filtre de champ → Operating Unit → Name (unité de l'employé)
SELECT
  hr_employee.departure_date                                        AS date_depart,
  hr_employee.name                                                  AS nom,
  COALESCE(CASE WHEN jsonb_typeof(to_jsonb(operating_unit.name)) = 'object' THEN COALESCE(to_jsonb(operating_unit.name)->>'fr_FR', to_jsonb(operating_unit.name)->>'en_US') ELSE to_jsonb(operating_unit.name)#>>'{}' END, 'Sans unité')              AS unite,
  COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_department.name)) = 'object' THEN COALESCE(to_jsonb(hr_department.name)->>'fr_FR', to_jsonb(hr_department.name)->>'en_US') ELSE to_jsonb(hr_department.name)#>>'{}' END, 'Sans département')         AS departement,
  COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_job.name)) = 'object' THEN COALESCE(to_jsonb(hr_job.name)->>'fr_FR', to_jsonb(hr_job.name)->>'en_US') ELSE to_jsonb(hr_job.name)#>>'{}' END, NULLIF(hr_employee.job_title, ''), 'Non renseigné') AS poste,
  COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_departure_reason.name)) = 'object' THEN COALESCE(to_jsonb(hr_departure_reason.name)->>'fr_FR', to_jsonb(hr_departure_reason.name)->>'en_US') ELSE to_jsonb(hr_departure_reason.name)#>>'{}' END, 'Non renseigné')      AS motif,
  hr_employee.date_ru                                               AS date_recrutement,
  CASE WHEN hr_employee.date_ru IS NULL THEN NULL
       ELSE date_part('year', age(hr_employee.departure_date, hr_employee.date_ru))::int END AS anciennete_au_depart,
  CASE WHEN hr_employee.birthday IS NULL THEN NULL
       ELSE date_part('year', age(hr_employee.departure_date, hr_employee.birthday))::int END AS age_au_depart
FROM hr_employee
LEFT JOIN hr_department       ON hr_department.id       = hr_employee.department_id
LEFT JOIN operating_unit      ON operating_unit.id      = hr_employee.default_operating_unit_id
LEFT JOIN hr_job              ON hr_job.id              = hr_employee.job_id
LEFT JOIN hr_departure_reason ON hr_departure_reason.id = hr_employee.departure_reason_id
WHERE hr_employee.departure_date IS NOT NULL
  AND hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
  AND TRUE /* perimetre:hr_employee.default_operating_unit_id */  -- unités de l'utilisateur (remplacé par le script de copie)
  [[AND EXTRACT(YEAR FROM hr_employee.departure_date) = {{annee}}]]
  [[AND hr_employee.departure_date >= {{date_debut}}]]
  [[AND hr_employee.departure_date <= {{date_fin}}]]
  -- sans aucun filtre (année ni dates) : année en cours
  AND (EXTRACT(YEAR FROM hr_employee.departure_date) = EXTRACT(YEAR FROM CURRENT_DATE)
       [[OR {{annee}} IS NOT NULL]] [[OR {{date_debut}} IS NOT NULL]] [[OR {{date_fin}} IS NOT NULL]])
  [[AND CASE WHEN jsonb_typeof(to_jsonb(hr_departure_reason.name)) = 'object' THEN COALESCE(to_jsonb(hr_departure_reason.name)->>'fr_FR', to_jsonb(hr_departure_reason.name)->>'en_US') ELSE to_jsonb(hr_departure_reason.name)#>>'{}' END = {{motif}}]]
  [[AND {{departement}}]]
  [[AND {{unite}}]]
ORDER BY date_depart DESC, nom
