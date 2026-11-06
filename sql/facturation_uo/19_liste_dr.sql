-- Liste des directions régionales
-- Sert de source pour la liste déroulante du filtre « Direction régionale »
-- du tableau de bord (Valeurs → Depuis une question → cette question).
SELECT name AS direction_regionale
FROM operating_unit
WHERE is_dr = true
ORDER BY name;
