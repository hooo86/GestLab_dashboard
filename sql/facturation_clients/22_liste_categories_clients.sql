-- Liste des catégories clients (modèle family.customer)
-- Sert de source à la liste déroulante du filtre « Catégorie client ».
SELECT DISTINCT
  CASE WHEN jsonb_typeof(to_jsonb(name)) = 'object'
       THEN COALESCE(to_jsonb(name)->>'fr_FR', to_jsonb(name)->>'en_US')
       ELSE to_jsonb(name)#>>'{}' END AS categorie
FROM family_customer
WHERE id <> 1005  -- famille « client interne » exclue
ORDER BY 1;
