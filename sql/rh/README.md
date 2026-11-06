# Ressources humaines

## Pyramide des âges

| Fichier | Contenu | Visualisation |
|---|---|---|
| `50_pyramide_des_ages.sql` | Effectifs par tranche de 5 ans, hommes et femmes côte à côte | Barres |
| `51_tableau_ages.sql` | Effectifs par tranche (hommes, femmes, autre), part en %, âge moyen, ligne TOTAL | Tableau |

**Règles**
- Seuls les **employés actifs** sont comptés (fiche employé non archivée).
- L'âge est calculé à partir de la **date de naissance** (onglet Informations privées), à la **date d'arrêté**.
- Les employés sans date de naissance apparaissent dans « Non renseigné » (tableau 51 uniquement).
- La date d'arrêté ne change que le calcul de l'âge : la liste des employés reste celle d'aujourd'hui.

**Variables Metabase (facultatives)**
- `date_arrete` : **Date** (sans valeur : aujourd'hui)
- `departement` : **Filtre de champ** → **Hr Department → Name** (choix multiple possible)

**Construire le graphique (question 50)**
1. Visualisation → **Barres**.
2. ⚙️ → **Données** : axe X = `tranche`, séries = `hommes` et `femmes`.
3. ⚙️ → **Affichage** : **ne pas empiler** (barres côte à côte) et activer **Afficher les valeurs sur les points de données**.
4. Couleurs : par exemple bleu pour les hommes, orange pour les femmes.
