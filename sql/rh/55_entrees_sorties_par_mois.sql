-- Entrées et sorties par mois, effectif de début et de fin de mois, taux de sortie
-- Entrée = date de recrutement (date_ru) dans le mois. Sortie = date de départ (departure_date) dans le mois.
-- Effectif = règle habituelle (type « Employé », recrutés à la date, pas encore partis).
-- Taux de sortie = sorties du mois / effectif de début de mois.
-- Visualisation : Barres (X = mois, Y = entrees et sorties) ; Tableau pour le détail
-- Filtres Metabase (facultatifs) :
--   {{annee}}         Nombre (sans valeur : année en cours)
--   {{departement}}   Filtre de champ → Hr Department → Name
--   {{unite}}         Filtre de champ → Operating Unit → Name (unité de l'employé)
WITH mois AS (
  SELECT d::date AS debut, (d + INTERVAL '1 month - 1 day')::date AS fin
  FROM generate_series(
         make_date(COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))::int, 1, 1),
         LEAST(make_date(COALESCE([[{{annee}}, ]] EXTRACT(YEAR FROM CURRENT_DATE))::int, 12, 1),
               date_trunc('month', CURRENT_DATE)::date),
         INTERVAL '1 month') AS d
),
employes AS (
  SELECT hr_employee.id, hr_employee.date_ru, hr_employee.departure_date, hr_employee.active
  FROM hr_employee
  LEFT JOIN hr_department  ON hr_department.id  = hr_employee.department_id
  LEFT JOIN operating_unit ON operating_unit.id = hr_employee.default_operating_unit_id
  LEFT JOIN hr_job         ON hr_job.id         = hr_employee.job_id
  WHERE TRUE
    AND hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
    AND TRUE /* perimetre:hr_employee.default_operating_unit_id */  -- unités de l'utilisateur (remplacé par le script de copie)
    [[AND {{departement}}]]
    [[AND {{unite}}]]
)
SELECT
  to_char(m.debut, 'YYYY-MM') AS mois,
  (SELECT COUNT(*) FROM employes e
    WHERE (e.date_ru IS NULL OR e.date_ru < m.debut)
      AND (e.departure_date >= m.debut OR (e.departure_date IS NULL AND e.active))) AS effectif_debut,
  (SELECT COUNT(*) FROM employes e WHERE e.date_ru BETWEEN m.debut AND m.fin)         AS entrees,
  (SELECT COUNT(*) FROM employes e WHERE e.departure_date BETWEEN m.debut AND m.fin)  AS sorties,
  (SELECT COUNT(*) FROM employes e
    WHERE (e.date_ru IS NULL OR e.date_ru <= m.fin)
      AND (e.departure_date > m.fin OR (e.departure_date IS NULL AND e.active)))    AS effectif_fin,
  ROUND(100.0 * (SELECT COUNT(*) FROM employes e WHERE e.departure_date BETWEEN m.debut AND m.fin)
        / NULLIF((SELECT COUNT(*) FROM employes e
                   WHERE (e.date_ru IS NULL OR e.date_ru < m.debut)
                     AND (e.departure_date >= m.debut OR (e.departure_date IS NULL AND e.active))), 0), 2) AS taux_sortie_pct
FROM mois m
ORDER BY m.debut
