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

**Construire le graphique (question 50)**
1. Visualisation → **Barres**.
2. ⚙️ → **Données** : axe X = `tranche`, séries = `hommes` et `femmes`.
3. ⚙️ → **Affichage** : **ne pas empiler** (barres côte à côte) et activer **Afficher les valeurs sur les points de données**.
4. Couleurs : par exemple bleu pour les hommes, orange pour les femmes.
