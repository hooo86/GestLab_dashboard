# Facturation par catégorie client

La **catégorie client** correspond aux **étiquettes** des contacts Odoo
(Contacts → Configuration → Étiquettes). On prend les étiquettes de la **société cliente** de la facture.

Les montants sont en HT, sur les factures clients validées, avoirs déduits. Un client sans étiquette apparaît dans « Sans catégorie ».

> Un client qui a **plusieurs étiquettes** compte dans chacune. La somme des catégories peut donc dépasser le CA total. La colonne `part_pct` est toujours calculée sur le CA total réel.

| Fichier | Indicateur | Visualisation |
|---|---|---|
| `20_ca_par_categorie_client.sql` | CA HT, nombre de clients et part (%) par catégorie | Barres horizontales (« Rangée ») ou Anneau |
| `21_ca_par_categorie_client_par_mois.sql` | CA HT par catégorie et par mois | Barres empilées ou Lignes (série = categorie) |
| `22_liste_categories_clients.sql` | Liste des catégories (sert au filtre) | Tableau |

## Variables à régler dans Metabase (cartes 20 et 21)

- `annee` : type **Nombre**, libellé « Année », valeur par défaut **2026**. Sans valeur, c'est l'année en cours.
- `categorie` : type **Texte**, libellé « Catégorie client »
- `unite` : **Filtre de champ** → **Operating Unit → Name**

## Filtre « Catégorie client » avec liste déroulante

1. Enregistrez la question `22_liste_categories_clients.sql` sous le nom « Liste des catégories clients ».
2. Dans le tableau de bord : ✏️ → **Ajouter un filtre** → **Texte ou catégorie**.
3. Réglages → **Valeurs** → **Depuis une autre question** → « Liste des catégories clients ».
4. Reliez-le à `categorie` sur les cartes 20 et 21. Reliez aussi les filtres **Année** et **Unité** existants.
