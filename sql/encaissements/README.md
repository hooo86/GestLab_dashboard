# Encaissements

Encaissements des factures clients, mois par mois.

## Règles de calcul

- **Uniquement les paiements lettrés avec une facture client.** Les paiements non lettrés (montants en circulation) ne sont pas comptés.
- **Uniquement les vrais encaissements** : paiements passés dans un journal **banque** ou **caisse**. Un avoir lettré avec une facture n'est pas un encaissement.
- **Montant** : la part du paiement lettrée sur la facture. Un paiement partiel compte pour sa part.
- **Date de l'encaissement** :
  - date du paiement, si elle est **postérieure** à la date de facture ;
  - sinon (paiement reçu avant la facture), **date de la facture**.
- Factures et paiements validés seulement. Famille client « client interne » (id 1005) exclue.
- Unité opérationnelle : celle de la **facture**.

| Fichier | Indicateur | Visualisation |
|---|---|---|
| `30_encaissements_par_mois.sql` | Montant encaissé et nombre de factures par mois | Barres (X = mois, Y = montant_encaisse) |
| `31_encaissements_par_uo_tableau_mensuel.sql` | Une ligne par unité, une colonne par mois, total + ligne TOTAL | Tableau |
| `32_encaissements_par_categorie_tableau_mensuel.sql` | Une ligne par classe client (`family_customer`), une colonne par mois, total + ligne TOTAL | Tableau |

## Variables à régler dans Metabase

- `annee` : type **Nombre**, libellé « Année ». Sans aucun filtre (ni année, ni dates), c'est l'année en cours.
- `date_debut` et `date_fin` : type **Date**, libellés « Encaissé du » et « Encaissé au ». Elles filtrent sur la **date d'encaissement** (date du paiement, ou date de la facture si le paiement est antérieur). Elles existent sur les cartes 30 à 34 et sont facultatives : on peut ne remplir que l'une des deux.
- `unite` : **Filtre de champ** → **Operating Unit → Name**
- `categorie` (carte 32) : type **Texte**, libellé « Classe client ». Liste déroulante : **Valeurs → Depuis une autre question** → « Liste des catégories clients » (question 22).

L'année filtre la **date de l'encaissement** : une facture de décembre 2025 payée en janvier 2026 compte en 2026.

## Encaissements par exercice de la facture (carte 33)

`33_encaissements_par_categorie_par_exercice.sql` regroupe les encaissements par **classe client** et par **exercice de la facture**, c'est-à-dire l'année de la **date de facturation**, quelle que soit la date du paiement.

Exemple : une facture de 2024 payée en 2024 puis en 2026 compte en entier dans l'exercice **2024**.

Lignes : détail catégorie × exercice, puis **Total catégorie**, puis **TOTAL** général. Visualisation : **Tableau**.

Variables (toutes facultatives) :
- `exercice` : **Nombre**, libellé « Exercice facture » (ex. 2024)
- `annee_encaissement` : **Nombre**, libellé « Année d'encaissement ». Elle sert par exemple à voir ce qui est rentré en 2026, réparti par exercice d'origine des factures.
- `categorie` : **Texte** (liste : question 22)
- `unite` : **Filtre de champ** → **Operating Unit → Name**

## Exercice en lignes, classe client en colonnes (carte 34)

`34_encaissements_exercice_x_categorie.sql` donne les mêmes chiffres que la carte 33, présentés en tableau croisé :

| exercice | Secteur public | Privé | TOTAL |
|---|---|---|---|
| Exercice 2024 | 1 000 | | 1 000 |
| Exercice 2025 | 300 | 700 | 1 000 |
| **TOTAL** | 1 300 | 700 | 2 000 |

La requête renvoie 3 colonnes (`exercice`, `categorie`, `montant_encaisse`), totaux compris. C'est Metabase qui met les catégories en colonnes. Une nouvelle catégorie créée dans Odoo apparaît donc toute seule.

Dans Metabase : **Visualisation → Tableau** → ⚙️ → activez **Pivoter le tableau** (colonne de pivot = `categorie`, cellule = `montant_encaisse`).

Variables : les mêmes que la carte 33 (`exercice`, `annee_encaissement`, `categorie`, `unite`).

## Filtre « Période d'encaissement » sur le tableau de bord

Le plus simple est d'ajouter **deux filtres Date → Date unique**, « Encaissé du » et « Encaissé au », reliés à `date_debut` et `date_fin` sur les cartes 30 à 34.

> Sur les tableaux 31 et 32 (une colonne par mois), une période à cheval sur deux années additionne les mois de même nom : décembre 2025 et décembre 2026 tombent dans la même colonne « Déc. ». Gardez une période d'au plus 12 mois.
