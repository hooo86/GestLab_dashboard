# Balance des créances clients

`40_balance_creances_par_mois.sql` donne, pour chaque mois, les créances clients en **fin de mois**.

## Règles de calcul

- Créance d'une facture : **montant TTC** de la facture client validée, diminué de ce qui a été **lettré** dessus.
- Chaque règlement lettré (encaissement, avoir ou autre) diminue la créance à sa **date d'effet** :
  - date du règlement, si elle est **après** la date de facture ;
  - sinon **date de la facture**.
- Exemples :
  - facture d'avril payée en mai : en créance fin avril, soldée fin mai ;
  - facture d'avril annulée par un avoir en mai : en créance fin avril, soldée fin mai (colonne « avoirs ») ;
  - facture de mars payée d'avance en février : jamais en créance.
- Les paiements et avoirs **non lettrés** ne diminuent pas les créances.
- Famille client « client interne » (id 1005) exclue.

## Colonnes

`creances_debut_mois` + `facture_mois` − `encaisse_mois` − `avoirs_mois` − `autres_reglements_mois` = `creances_fin_mois`

« Autres règlements » : lettrages par écriture diverse (pertes, écarts de change…).

Le mois en cours s'arrête à aujourd'hui. Sa créance de fin de mois correspond donc au reste à payer actuel dans Odoo.

## Variables Metabase (facultatives)

- `annee` : **Nombre**, défaut **2026** (sans valeur : année en cours)
- `categorie` : **Texte** (classe client ; liste : question 22)
- `unite` : **Filtre de champ** → **Operating Unit → Name**

Visualisation : **Tableau**, ou **Lignes** avec X = mois et Y = creances_fin_mois.

## Créances par exercice (lignes) et classe client (colonnes) — carte 41

`41_creances_exercice_x_categorie.sql` donne le **reste à encaisser à une date d'arrêté**. Les lignes sont l'**exercice de la facture** (année de la date de facturation), les colonnes la **classe client**, avec une colonne et une ligne **TOTAL**.

| exercice | Secteur public | Privé | TOTAL |
|---|---|---|---|
| Exercice 2024 | 600 | | 600 |
| Exercice 2025 | 300 | 500 | 800 |
| **TOTAL** | 900 | 500 | 1 400 |

Les règles sont les mêmes que pour la carte 40 : règlements et avoirs lettrés pris à leur date d'effet.

Dans Metabase : **Visualisation → Tableau** → ⚙️ → **Pivoter le tableau** (colonne de pivot = `categorie`, cellule = `creances`).

Variables (facultatives) :
- `date_arrete` : **Date**, libellé « Date d'arrêté ». Sans valeur, c'est aujourd'hui. Par exemple `31/12/2025` donne la situation de clôture 2025.
- `exercice` : **Nombre**
- `categorie` : **Texte** (liste : question 22)
- `unite` : **Filtre de champ** → **Operating Unit → Name**

## Par étiquette client : OPGI, AADL, ENPI, DEP, DUAC, DL, VN, CTC

Les colonnes sont **fixes** : OPGI, AADL, ENPI, DEP, DUAC, DL, VN, CTC, **Autres** (client sans aucune de ces étiquettes) et **TOTAL**. Les lignes sont les exercices de facture, avec une ligne **TOTAL**. Visualisation : **Tableau**, sans pivot.

- On lit les étiquettes de la **société cliente** et du **contact** de la facture. Les majuscules et les espaces sont ignorés (« aadl » = AADL).
- Un client qui a **plusieurs** de ces étiquettes est compté **une seule fois**, dans la première de la liste ci-dessus (OPGI avant AADL, etc.).
- Pour ajouter ou retirer une étiquette, modifiez la liste `VALUES (1, 'OPGI'), …` et les colonnes `FILTER (WHERE etiquette = …)` dans le fichier.

| `42_creances_exercice_x_etiquette.sql` | Créances à une date d'arrêté : exercice × étiquette. Variables : `date_arrete` (Date), `exercice` (Nombre), `unite` (Filtre de champ). |
