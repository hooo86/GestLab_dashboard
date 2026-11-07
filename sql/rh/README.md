# Ressources humaines

## Pyramide des âges

| Fichier | Contenu | Visualisation |
|---|---|---|
| `50_pyramide_des_ages.sql` | Effectifs par tranche de 5 ans, hommes et femmes côte à côte | Barres |
| `52_effectif_total.sql` | Effectif total, hommes, femmes, âge moyen | Nombre |
| `51_tableau_ages.sql` | Effectifs par tranche (hommes, femmes, autre), part en %, âge moyen, ligne TOTAL | Tableau |

**Règles : effectif à la date d'arrêté**
- Seuls les employés de type **Employé** sont comptés (`employee_type = employee`). Stagiaires, sous-traitants, etc. sont exclus.
- **Recrutés au plus tard à la date** (`date_ru`). Un employé recruté après la date n'est pas compté. Un employé sans date de recrutement est compté.
- **Encore présents à la date** : ceux partis **après** la date (`departure_date`) sont comptés, **même si leur fiche est archivée** aujourd'hui. Sans date de départ, seules les fiches actives sont comptées.
- L'âge est calculé à la **date d'arrêté**, d'après la date de naissance. Sans date de naissance : « Non renseigné » (tableau 51).

**Variables Metabase (facultatives)**
- `date_arrete` : **Date** (sans valeur : aujourd'hui)
- `departement` : **Filtre de champ** → **Hr Department → Name** (choix multiple possible)
- `unite` : **Filtre de champ** → **Operating Unit → Name** : unité de l'employé (`default_operating_unit_id`), choix multiple possible

**Tableaux de bord par utilisateur** : les requêtes RH contiennent le repère de périmètre sur l'unité de l'employé (`default_operating_unit_id`). Le script `outils/dupliquer_tableau.py` les limite donc aux unités de chaque utilisateur, comme pour la finance. Un employé sans unité n'apparaît que sur le tableau de bord modèle.

**Construire le graphique (question 50)**
1. Visualisation → **Barres**.
2. ⚙️ → **Données** : axe X = `tranche`, séries = `hommes` et `femmes`.
3. ⚙️ → **Affichage** : **ne pas empiler** (barres côte à côte) et activer **Afficher les valeurs sur les points de données**.
4. Couleurs : par exemple bleu pour les hommes, orange pour les femmes.

---

# Les 3 tableaux de bord RH

Toutes les requêtes suivent les mêmes règles :
- type **Employé** uniquement ;
- effectif à la date : recrutés (`date_ru`) au plus tard à la date, et partis (`departure_date`) après la date ou pas partis ;
- filtres facultatifs `departement` et `unite` (Filtres de champ, choix multiple) ;
- repère de périmètre pour les copies par utilisateur.

## Tableau de bord 1 — Effectifs (filtre : Date d'arrêté)

| Carte | Fichier | Visualisation |
|---|---|---|
| Effectif total | `52_effectif_total.sql` | Nombre |
| Pyramide des âges | `50_pyramide_des_ages.sql` | Barres, hommes / femmes côte à côte |
| Âges en détail | `51_tableau_ages.sql` | Tableau |
| Effectif par unité | `53_effectif_par_unite.sql` | Tableau : hommes, femmes, total, % femmes, âge et ancienneté moyens, TOTAL |
| Effectif par poste | `54_effectif_par_poste.sql` | Tableau ou barres horizontales (colonne total) |

```
[ 52 Effectif total ][ 50 Pyramide des âges (2 colonnes)        ]
[ 53 Effectif par unité (toute la largeur)                      ]
[ 54 Effectif par poste      ][ 51 Âges en détail               ]
```

## Tableau de bord 2 — Mouvements (filtre : Année)

| Carte | Fichier | Visualisation |
|---|---|---|
| Entrées / sorties par mois | `55_entrees_sorties_par_mois.sql` | Barres (X = mois, Y = entrees et sorties) |
| Détail mensuel | `55_entrees_sorties_par_mois.sql` (même requête) | Tableau : effectif début et fin, taux de sortie |
| Sorties par motif | `56_sorties_par_motif.sql` | Anneau (motif de départ de la fiche employé) |
| Liste des départs | `60_liste_departs.sql` | Tableau : date de départ, nom, unité, département, poste, motif, date de recrutement, ancienneté et âge au départ |

- **Entrée** : date de recrutement (`date_ru`) dans le mois. **Sortie** : date de départ (`departure_date`) dans le mois.
- **Taux de sortie** = sorties du mois / effectif au début du mois.
- Variable `annee` : **Nombre**. Sans valeur, c'est l'année en cours.

```
[ 55 Entrées / sorties par mois (graphique, toute la largeur)   ]
[ 55 Détail mensuel (tableau)   ][ 56 Sorties par motif         ]
[ 60 Liste des départs (toute la largeur)                       ]
```

Carte 60, variables : `annee` (Nombre), `date_debut` / `date_fin` (Date, période de départ), `motif` (Texte). Sans aucun filtre, c'est l'année en cours. Reliez le filtre **Année** du tableau de bord à `annee` sur les cartes 55, 56 et 60.

## Tableau de bord 3 — Ancienneté et retraites (filtres : Date d'arrêté, Âge de la retraite)

| Carte | Fichier | Visualisation |
|---|---|---|
| Ancienneté | `57_anciennete.sql` | Barres hommes / femmes : moins d'1 an, 1-4, 5-9, 10-14, 15-19, 20-24, 25 ans et plus |
| Départs à la retraite prévus | `58_departs_retraite_prevus.sql` | Barres par année (10 ans), ligne TOTAL en tableau |
| Liste des futurs retraités | `59_liste_departs_retraite.sql` | Tableau nominatif |

- Variable `age_retraite` : **Nombre**. Sans valeur : **60**. Mettez par exemple 55 pour simuler un départ anticipé.
- Variable `horizon` (carte 59) : **Nombre** d'années. Sans valeur : **5**.
- La carte 59 liste aussi les employés qui ont **déjà** dépassé l'âge de la retraite et sont toujours présents (date de retraite passée).

```
[ 57 Ancienneté               ][ 58 Départs à la retraite prévus ]
[ 59 Liste des futurs retraités (toute la largeur)              ]
```

## Filtres du tableau de bord

Pour chaque tableau de bord, ajoutez les filtres puis reliez-les à la variable du même nom sur **toutes** les cartes :
- **Date d'arrêté** (Date unique) → `date_arrete` (tableaux 1 et 3)
- **Année** (Nombre) → `annee` (tableau 2)
- **Âge de la retraite** (Nombre) → `age_retraite` (tableau 3)
- **Unité** (Texte, plusieurs valeurs) → `unite`
- **Département** (Texte, plusieurs valeurs) → `departement`
