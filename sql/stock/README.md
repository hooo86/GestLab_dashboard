# Valorisation du stock

| Fichier | Contenu | Visualisation |
|---|---|---|
| `61_valorisation_stock_par_famille.sql` | Par **famille d'articles** (catégorie) : valeur de départ, entrées, sorties, valeur finale, ligne TOTAL | Tableau |
| `62_valorisation_stock_par_article.sql` | Même chose **par article**, avec sa famille | Tableau |

## Règles de calcul

Source : la **valorisation du stock d'Odoo** (`stock_valuation_layer`). Chaque mouvement de stock valorisé y laisse une ligne avec sa quantité et sa valeur. Ce sont les mêmes chiffres que le rapport Odoo **Inventaire → Rapports → Valorisation**.

Pour une période *du … au …* :
- **valeur de départ** : somme des mouvements **avant** le début de la période, c'est-à-dire la valeur du stock la veille ;
- **entrées** : mouvements de la période qui **ajoutent** du stock (quantité positive : réceptions, retours, ajustements +) ;
- **sorties** : mouvements de la période qui **retirent** du stock (quantité négative : livraisons, consommations, ajustements −), affichés en positif ;
- **valeur finale** = départ + entrées − sorties : valeur du stock à la fin de la période.

Les **réévaluations** (changement de coût sans quantité) vont en entrée si elles augmentent la valeur, en sortie si elles la diminuent. Les dates sont en **heure d'Algérie**.

Seuls les articles **stockables valorisés** apparaissent. Les **catégories d'investissement** (`is_categorie_investissement` coché) sont **exclues**. Les familles sans aucun mouvement ni stock sont masquées.

## Variables Metabase (facultatives)

- `date_debut` et `date_fin` : **Date**, libellés « Du » et « Au ». Sans valeur : du 1er janvier de l'année en cours à aujourd'hui.
- `famille` : **Filtre de champ** → **Product Category → Complete Name**, choix multiple.

## Unité opérationnelle

Filtre `unite` : **Filtre de champ** → **Operating Unit → Name**, choix multiple. Il sert aussi au périmètre des copies par utilisateur.

L'unité d'un mouvement est celle de l'**emplacement de stock** qui détient la marchandise : l'emplacement de **destination** pour une entrée, l'emplacement d'**origine** pour une sortie. Elle est cherchée sur l'emplacement, puis sur son **entrepôt**, puis sur le transfert et sur le mouvement, et le premier renseigné est retenu.

Les **réévaluations de coût**, qui ne sont liées à aucun mouvement, n'ont pas d'unité : elles ne comptent que sans filtre Unité. Si aucune unité n'est renseignée nulle part dans votre Odoo, le filtre Unité renvoie des cartes vides.
