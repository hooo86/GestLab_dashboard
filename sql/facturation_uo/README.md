# Facturation par unité opérationnelle

Indicateurs pour Odoo Community avec le module OCA **`account_operating_unit`**
(champ « Unité opérationnelle » sur les factures).

Toutes les requêtes portent sur les **factures clients validées**, avoirs déduits, en **HT** et dans la devise de la société. Les brouillons et les factures annulées sont exclus. Une facture sans unité apparaît dans « Sans unité ».

## 0. Vérification préalable

À lancer une fois dans Metabase. Elle doit afficher la liste de vos unités et leur nombre de factures :

```sql
SELECT ou.name AS unite, COUNT(m.id) AS nb_factures
FROM operating_unit ou
LEFT JOIN account_move m ON m.operating_unit_id = ou.id
                        AND m.move_type = 'out_invoice' AND m.state = 'posted'
GROUP BY ou.name
ORDER BY nb_factures DESC;
```

## 1. Les indicateurs

| Fichier | Indicateur | Visualisation | Filtres |
|---|---|---|---|
| `10_ca_par_uo_par_mois.sql` | CA HT par unité et par mois | Barres empilées (série = unite) | année, unité |
| `11_repartition_ca_par_uo.sql` | Part de chaque unité dans le CA | Anneau | année, unité |
| `12_ca_uo_annee_n_vs_n1.sql` | CA depuis le 1er janvier vs même période N-1 | Tableau ou barres groupées | unité |
| `13_impayes_par_uo_anciennete.sql` | Reste à encaisser par ancienneté du retard | Barres empilées | unité |
| `14_top_clients_par_uo.sql` | 10 meilleurs clients de chaque unité | Tableau | année, unité |
| `15_chiffres_cles_par_uo.sql` | CA du mois, CA de l'année, nb factures, à encaisser | Tableau ou cartes « Nombre » | unité |
| `16_ca_par_uo_par_annee.sql` | CA HT par unité et par année | Barres groupées (X = annee, série = unite) | année, unité |

## 2. Régler les filtres dans Metabase (une seule fois par question)

Les requêtes contiennent `{{annee}}` et `{{unite}}`. Après avoir collé la requête, Metabase ouvre à droite le panneau **Variables**. Réglez :

**`unite`**
- Type de variable : **Filtre de champ**
- Champ : **Operating Unit → Name**
- Type de widget : **Chaîne de caractères** (liste déroulante)

**`annee`**
- Type de variable : **Nombre**
- Libellé : **Année**
- (facultatif) Valeur par défaut : l'année en cours, par exemple `2026`

Les filtres sont facultatifs : sans valeur, la requête prend tout.

## 3. Le tableau de bord « Facturation par unité »

1. Créez un tableau de bord **Facturation par unité**.
2. Ajoutez les 7 questions, dans cette disposition :
   ```
   [ 15 Chiffres clés — toute la largeur          ]
   [ 10 CA par mois — toute la largeur            ]
   [ 11 Répartition    ][ 12 N vs N-1             ]
   [ 13 Impayés        ][ 14 Top clients          ]
   [ 16 CA par année — toute la largeur           ]
   ```
3. Cliquez sur ✏️ puis **Ajouter un filtre** :
   - **Unité** (type Texte) : reliez-le à la variable `unite` de chaque carte.
   - **Année** (type **Nombre**, « Égal à ») : reliez-le à `annee` sur les cartes 10, 11, 14 et 16.
     Pour avoir une liste déroulante : dans les réglages du filtre, choisissez **Valeurs → Liste personnalisée** et saisissez les années (2023, 2024, 2025, 2026…).
4. Enregistrez. Un seul choix d'unité ou d'année met alors toutes les cartes à jour.

> Les cartes 12, 13 et 15 ne suivent pas le filtre Année : elles comparent l'année en cours à l'an dernier ou montrent les impayés du moment.

## 4. Chiffre d'affaires par direction régionale (DR)

La DR d'une facture est :
- son unité opérationnelle, si cette unité est elle-même une DR (`is_dr` coché) ;
- sinon la DR parente de l'unité (`parent_dr_id`).

Une unité qui n'est pas une DR et n'a pas de DR parente apparaît dans « Sans DR ».

| Fichier | Indicateur | Visualisation |
|---|---|---|
| `17_ca_par_dr_par_mois.sql` | CA HT par DR et par mois | Barres empilées ou Lignes (X = mois, série = direction_regionale) |
| `18_ca_par_dr_tableau_mensuel.sql` | Tableau : une ligne par DR, une colonne par mois + total | Tableau |
| `19_liste_dr.sql` | Liste des DR (sert au filtre) | Tableau |

**Variables à régler dans Metabase (cartes 17 et 18)**
- `annee` : type **Nombre**, libellé « Année », valeur par défaut **2026**
- `dr` : type **Texte**, libellé « Direction régionale »

Sans valeur pour l'année, la carte 18 prend l'année en cours.

**Filtre « Direction régionale » du tableau de bord, avec liste déroulante**
1. Enregistrez d'abord la question `19_liste_dr.sql` sous le nom « Liste des DR ».
2. Dans le tableau de bord : ✏️ → **Ajouter un filtre** → **Texte ou catégorie**.
3. Réglages du filtre → **Valeurs** → **Depuis une autre question** → « Liste des DR », colonne `direction_regionale`.
4. Reliez le filtre à la variable `dr` des cartes 17 et 18, et le filtre **Année** à leur variable `annee`.

## 5. Date d'arrêté (cartes 13 et 15, et 03 dans `sql/indicateurs/`)

Ces cartes se calculent à une **date d'arrêté** au choix. Sans valeur, c'est aujourd'hui.

- Variable `date_arrete` : type **Date**, libellé « Date d'arrêté ».
- **Reste à encaisser** : TTC des factures émises jusqu'à cette date, moins les règlements et avoirs lettrés dont la date d'effet est au plus tard à cette date. C'est la même règle que pour les créances (dossier `sql/creances/`).
- **Retard** (carte 13 et carte 03) : compté à la date d'arrêté.
- **CA du mois et de l'année** (carte 15) : mois et année de la date d'arrêté, jusqu'à cette date.

Sur le tableau de bord, ajoutez un filtre **Date** (« Date unique ») nommé « Date d'arrêté » et reliez-le à `date_arrete` sur les cartes 03, 13, 15 et 41.
