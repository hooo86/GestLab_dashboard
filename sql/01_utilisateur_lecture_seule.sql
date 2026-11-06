-- Crée un utilisateur PostgreSQL en LECTURE SEULE pour Metabase.
-- À exécuter sur la base Odoo, en tant que superutilisateur PostgreSQL :
--   psql -U postgres -d NOM_BASE_ODOO -f sql/01_utilisateur_lecture_seule.sql
--
-- Avant de lancer :
--   1. remplacez 'changez-moi' par un vrai mot de passe ;
--   2. remplacez "odoo" (plus bas) si l'utilisateur PostgreSQL d'Odoo a un autre nom.

CREATE ROLE metabase_lecture LOGIN PASSWORD 'changez-moi';

-- Connexion à la base Odoo courante
DO $$
BEGIN
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO metabase_lecture', current_database());
END
$$;

-- Lecture des tables existantes
GRANT USAGE ON SCHEMA public TO metabase_lecture;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_lecture;

-- Lecture des tables créées plus tard par Odoo (installation de nouveaux modules)
ALTER DEFAULT PRIVILEGES FOR ROLE odoo IN SCHEMA public
  GRANT SELECT ON TABLES TO metabase_lecture;

-- Sécurité : empêche toute écriture, même par erreur
ALTER ROLE metabase_lecture SET default_transaction_read_only = on;
