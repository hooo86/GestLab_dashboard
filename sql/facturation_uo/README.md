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
| `10_ca_par_uo_par_mois.sql` | CA HT par unité et par mois | Barres empilées (série = unite) | période, unité |
| `11_repartition_ca_par_uo.sql` | Part de chaque unité dans le CA | Anneau | période, unité |
| `12_ca_uo_annee_n_vs_n1.sql` | CA depuis le 1er janvier vs même période N-1 | Tableau ou barres groupées | unité |
| `13_impayes_par_uo_anciennete.sql` | Reste à encaisser par ancienneté du retard | Barres empilées | unité |
| `14_top_clients_par_uo.sql` | 10 meilleurs clients de chaque unité | Tableau | période, unité |
| `15_chiffres_cles_par_uo.sql` | CA du mois, CA de l'année, nb factures, à encaisser | Tableau ou cartes « Nombre » | unité |

## 2. Régler les filtres dans Metabase (une seule fois par question)

Les requêtes contiennent `{{periode}}` et `{{unite}}`. Après avoir collé la requête, Metabase ouvre à droite le panneau **Variables**. Réglez :

**`unite`**
- Type de variable : **Filtre de champ**
- Champ : **Operating Unit → Name**
- Type de widget : **Chaîne de caractères** (liste déroulante)

**`periode`**
- Type de variable : **Filtre de champ**
- Champ : **Account Move → Invoice Date**
- Type de widget : **Toutes les options de date**

Les filtres sont facultatifs : sans valeur, la requête prend tout.

## 3. Le tableau de bord « Facturation par unité »

1. Créez un tableau de bord **Facturation par unité**.
2. Ajoutez les 6 questions, dans cette disposition :
   ```
   [ 15 Chiffres clés — toute la largeur          ]
   [ 10 CA par mois — toute la largeur            ]
   [ 11 Répartition    ][ 12 N vs N-1             ]
   [ 13 Impayés        ][ 14 Top clients          ]
   ```
3. Cliquez sur ✏️ puis **Ajouter un filtre** :
   - **Unité** (type Texte) : reliez-le à la variable `unite` de chaque carte.
   - **Période** (type Date, « Toutes les options ») : reliez-le à `periode` sur les cartes 10, 11 et 14.
4. Enregistrez. Un seul choix d'unité ou de période met alors toutes les cartes à jour.
