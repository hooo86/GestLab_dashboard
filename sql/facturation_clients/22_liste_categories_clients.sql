-- Liste des catégories clients (étiquettes de contact)
-- Sert de source à la liste déroulante du filtre « Catégorie client ».
SELECT DISTINCT COALESCE(name->>'fr_FR', name->>'en_US') AS categorie
FROM res_partner_category
WHERE active
ORDER BY 1;
