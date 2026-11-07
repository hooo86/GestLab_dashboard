-- Pyramide des âges : employés actifs par tranche de 5 ans, hommes / femmes
-- Effectif à la date d'arrêté (sans valeur : aujourd'hui) : type « Employé », recrutés
-- (date_ru) au plus tard à cette date, partis (departure_date) après cette date ou pas partis.
-- Âge calculé à la date d'arrêté, d'après la date de naissance.
-- Visualisation : Barres (X = tranche, séries = hommes et femmes côte à côte, non empilées)
--   ⚙️ Affichage : « Afficher les valeurs sur les points de données »
-- Filtres Metabase (facultatifs) :
--   {{date_arrete}}   Date
--   {{departement}}   Filtre de champ → Hr Department → Name
--   {{unite}}         Filtre de champ → Operating Unit → Name (unité de l'employé)
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
  LEFT JOIN operating_unit ON operating_unit.id = hr_employee.default_operating_unit_id
  WHERE hr_employee.employee_type = 'employee'        -- type « Employé » uniquement
    -- Recruté au plus tard à la date d'arrêté (date de recrutement inconnue : compté)
    AND (hr_employee.date_ru IS NULL OR hr_employee.date_ru <= parametres.date_arrete)
    -- Encore présent à la date d'arrêté :
    --   parti après cette date (même archivé aujourd'hui), ou pas de date de départ et fiche active
    AND (hr_employee.departure_date > parametres.date_arrete
         OR (hr_employee.departure_date IS NULL AND hr_employee.active))
    AND TRUE /* perimetre:hr_employee.default_operating_unit_id */  -- unités de l'utilisateur (remplacé par le script de copie)
    [[AND {{departement}}]]
    [[AND {{unite}}]]
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
  COUNT(t.ordre) FILTER (WHERE t.gender = 'male')   AS hommes,
  COUNT(t.ordre)  FILTER (WHERE t.gender = 'female') AS femmes
FROM toutes
LEFT JOIN tranches t ON t.ordre = toutes.ordre   -- sans date de naissance : voir la requête 51
GROUP BY toutes.ordre, toutes.tranche
-- des plus jeunes aux plus âgés
ORDER BY toutes.ordre;
