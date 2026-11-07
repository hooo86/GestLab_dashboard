-- Sorties de l'année par motif de départ (fiche employé → Motif du départ)
-- Visualisation : Anneau (dimension = motif, mesure = sorties) ; Tableau pour les %
-- Filtres Metabase (facultatifs) :
--   {{annee}}         Nombre (sans valeur : année en cours)
--   {{departement}}   Filtre de champ → Hr Department → Name
--   {{unite}}         Filtre de champ → Operating Unit → Name (unité de l'employé)
SELECT
  COALESCE(CASE WHEN jsonb_typeof(to_jsonb(hr_departure_reason.name)) = 'object' THEN COALESCE(to_jsonb(hr_departure_reason.name)->>'fr_FR', to_jsonb(hr_departure_reason.name)->>'en_US') ELSE to_jsonb(hr_departure_reason.name)#>>'{}' END, 'Non renseigné') AS motif,
  COUNT(*) AS sorties,
  ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 1) AS part_pct
  FROM hr_employee
  LEFT JOIN hr_department  ON hr_department.id  = hr_employee.department_id
  LEFT JOIN operating_unit ON operating_unit.id = hr_employee.default_operating_unit_id
  LEFT JOIN hr_job         ON hr_job.id         = hr_employee.job_id
  LEFT JOIN hr_departure_reason ON hr_departure_reason.id = hr_employee.departure_reason_id
  WHERE EXTRACT(YEAR FROM hr_employee.departure_date) =
        COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))
    AND hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
    AND TRUE /* perimetre:hr_employee.default_operating_unit_id */  -- unités de l'utilisateur (remplacé par le script de copie)
    [[AND {{departement}}]]
    [[AND {{unite}}]]
GROUP BY 1
ORDER BY sorties DESC
