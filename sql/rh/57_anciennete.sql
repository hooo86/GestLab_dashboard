-- Ancienneté à la date d'arrêté (depuis la date de recrutement date_ru), par tranche, hommes / femmes
-- Effectif à la date : type « Employé », recrutés (date_ru) au plus tard à la date,
-- partis (departure_date) après la date ou pas partis (fiche active).
-- Visualisation : Barres (X = tranche, séries = hommes et femmes, non empilées, valeurs affichées)
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}   Date (sans valeur : aujourd'hui)
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
tranches(ordre, tranche, mini, maxi) AS (
  VALUES (1, 'Moins d''1 an', 0, 0), (2, '1 à 4 ans', 1, 4), (3, '5 à 9 ans', 5, 9),
         (4, '10 à 14 ans', 10, 14), (5, '15 à 19 ans', 15, 19), (6, '20 à 24 ans', 20, 24),
         (7, '25 ans et plus', 25, 999), (8, 'Non renseignée', NULL, NULL)
)
SELECT
  t.tranche,
  COUNT(e.id) FILTER (WHERE e.gender = 'male')   AS hommes,
  COUNT(e.id) FILTER (WHERE e.gender = 'female') AS femmes,
  COUNT(e.id)                                    AS total
FROM tranches t
LEFT JOIN employes e
  ON (t.mini IS NULL AND e.anciennete IS NULL)
  OR (e.anciennete BETWEEN t.mini AND t.maxi)
GROUP BY t.ordre, t.tranche
ORDER BY t.ordre
