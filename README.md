# GestLab Dashboard

Tableaux de bord pour **Odoo Community** avec **Metabase** (gratuit, open source).

Metabase lit directement la base PostgreSQL d'Odoo, avec un utilisateur **en lecture seule** : il ne peut rien modifier dans Odoo.

## Contenu

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` | Lance Metabase et sa base interne |
| `.env.example` | Réglages (mot de passe, port, fuseau horaire) |
| `sql/01_utilisateur_lecture_seule.sql` | Crée l'utilisateur PostgreSQL en lecture seule |
| `sql/indicateurs/*.sql` | Requêtes prêtes à coller dans Metabase |

## Installation

Il faut Docker sur le serveur (ou un PC qui peut joindre la base Odoo).

### 1. Créer l'utilisateur en lecture seule

Ouvrez `sql/01_utilisateur_lecture_seule.sql` et changez le mot de passe `changez-moi`.
Si l'utilisateur PostgreSQL d'Odoo ne s'appelle pas `odoo`, changez-le aussi.

Puis, sur le serveur de la base Odoo :

```bash
sudo -u postgres psql -d NOM_BASE_ODOO -f sql/01_utilisateur_lecture_seule.sql
```

### 2. Autoriser Metabase à se connecter à PostgreSQL

Seulement si Metabase n'est **pas** sur la même machine qu'Odoo, ou si PostgreSQL n'accepte que les connexions locales :

- `postgresql.conf` : `listen_addresses = '*'`
- `pg_hba.conf` : ajouter par exemple
  `host  NOM_BASE_ODOO  metabase_lecture  172.16.0.0/12  scram-sha-256`
  (réseau Docker ; adaptez l'adresse à votre cas)
- Redémarrer PostgreSQL : `sudo systemctl restart postgresql`

### 3. Lancer Metabase

```bash
cp .env.example .env      # puis changez le mot de passe dans .env
docker compose up -d
```

Attendez 1 à 2 minutes, puis ouvrez **http://localhost:3000** (ou `http://IP_DU_SERVEUR:3000`).

### 4. Connecter Odoo dans Metabase

À la première ouverture, Metabase crée le compte administrateur, puis demande la base de données :

| Champ | Valeur |
|---|---|
| Type | PostgreSQL |
| Hôte | `host.docker.internal` si PostgreSQL est sur la même machine, sinon son adresse IP |
| Port | `5432` |
| Base de données | nom de votre base Odoo |
| Utilisateur | `metabase_lecture` |
| Mot de passe | celui choisi à l'étape 1 |

> Si Odoo tourne lui aussi dans Docker, l'hôte est le nom du conteneur PostgreSQL (par exemple `db`), à condition que les deux soient sur le même réseau Docker.

### 5. Créer les indicateurs

Dans Metabase : **Nouveau → Requête SQL**, collez un fichier de `sql/indicateurs/`, lancez, choisissez le graphique, puis **Enregistrer** et **Ajouter au tableau de bord**.

| Fichier | Indicateur | Module Odoo |
|---|---|---|
| `01_ca_par_mois.sql` | Chiffre d'affaires HT par mois | Facturation |
| `02_top_clients.sql` | 10 meilleurs clients (12 mois) | Facturation |
| `03_factures_impayees.sql` | Factures impayées et jours de retard | Facturation |
| `04_ventes_par_commercial.sql` | Ventes par commercial et par mois | Ventes |
| `05_devis_en_cours.sql` | Devis non confirmés | Ventes |
| `06_stock_par_produit.sql` | Stock par produit | Inventaire |

Les requêtes sont prévues pour **Odoo 16, 17 et 18**. Un indicateur dont le module n'est pas installé renverra une erreur : ignorez-le.

## Commandes utiles

```bash
docker compose ps          # état
docker compose logs -f metabase   # journaux
docker compose pull && docker compose up -d   # mise à jour (après avoir changé la version dans docker-compose.yml)
docker compose down        # arrêt (les tableaux de bord sont conservés)
```

## Sécurité

- Ne publiez jamais le fichier `.env` (il est ignoré par git).
- Pour un accès depuis internet, placez Metabase derrière un proxy HTTPS (Nginx, Caddy…).
