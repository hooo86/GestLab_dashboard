-- Liste des catégories clients (valeurs du champ family_customer)
-- Sert de source à la liste déroulante du filtre « Catégorie client ».
SELECT COALESCE(s.name->>'fr_FR', s.name->>'en_US', s.value) AS categorie
FROM ir_model_fields_selection s
JOIN ir_model_fields f ON f.id = s.field_id
WHERE f.model = 'res.partner' AND f.name = 'family_customer'
ORDER BY s.sequence;
