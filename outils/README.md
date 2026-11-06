# Tableaux de bord par direction régionale (DR)

La version gratuite de Metabase ne sait pas limiter les lignes visibles selon l'utilisateur. On crée donc **une copie de chaque tableau de bord par DR**. Dans chaque copie, la DR est écrite en dur dans le SQL et la copie est rangée dans une collection réservée à cette DR. L'utilisateur, qui n'a que le droit de lecture, ne peut pas changer de DR.

Le script `dupliquer_par_dr.py` fait ces copies automatiquement.

## 1. Préparer le tableau de bord modèle (une fois)

1. Sur la VM Metabase : `cd ~/GestLab_dashboard && git pull`.
2. Dans le tableau de bord modèle, **recollez chaque question** depuis le fichier du dépôt. Toutes les requêtes de facturation, encaissements et créances contiennent maintenant le filtre `{{dr}}`.
3. Dans chaque question, réglez la variable `dr` : type **Texte**, libellé « Direction régionale », **non obligatoire**.
4. (Facultatif) Sur le modèle, ajoutez un filtre **Direction régionale** relié à `dr`. C'est utile pour la direction générale, qui peut ainsi choisir une DR. Le script le retire des copies.

La DR d'une facture est celle de son **unité opérationnelle** : l'unité elle-même si `is_dr` est coché, sinon `parent_dr_id`.

## 2. Lancer le script (sur la VM Metabase)

Retrouvez l'**id du tableau de bord** dans son adresse : `http://192.168.8.26:3000/dashboard/5-finance` → id **5**.

Essai, qui ne modifie rien :
```bash
python3 outils/dupliquer_par_dr.py --email hocineinfo@gmail.com --tableau 5 --toutes-dr --essai
```
Lancement réel, pour toutes les DR :
```bash
python3 outils/dupliquer_par_dr.py --email hocineinfo@gmail.com --tableau 5 --toutes-dr
```
Pour une ou quelques DR seulement :
```bash
python3 outils/dupliquer_par_dr.py --email hocineinfo@gmail.com --tableau 5 --dr "DR Centre" --dr "DR Est"
```
Options utiles :
- `--prefixe "Tableaux – "` : préfixe du nom des collections créées ;
- `--collection-parent 12` : crée les collections DR dans la collection n° 12 ;
- `--base Odoo` : nom de la base Odoo dans Metabase (pour `--toutes-dr`).

Le script demande votre mot de passe Metabase. Il crée une collection par DR, ou réutilise celle qui porte déjà ce nom.

⚠ Si le script signale une question **sans `{{dr}}`**, cette question montrerait toutes les DR. Recollez-la depuis le dépôt, puis relancez le script, ou supprimez-la de la copie.

Pour refaire les copies après une modification du modèle : supprimez (mettez à la corbeille) les anciens tableaux de bord DR, puis relancez le script.

## 3. Donner les droits (une fois par DR)

1. **Admin → Personnes → Groupes** : créez un groupe par DR (par exemple « DR Centre ») et ajoutez-y ses utilisateurs.
2. **Admin → Autorisations → Collections** :
   - collection **« DR Centre »** : groupe « DR Centre » = **Afficher** ;
   - toutes les autres collections, et « Nos analyses » : groupe « DR Centre » = **Pas d'accès** ;
   - groupe **Tous les utilisateurs** : **Pas d'accès** partout.
3. **Admin → Autorisations → Données → Odoo**, pour chaque groupe DR :
   - **Voir les données** : Peut voir ;
   - **Créer des requêtes** : **Non**. C'est indispensable : sinon l'utilisateur pourrait modifier le SQL et voir les autres DR.

## Limite

La liste déroulante du filtre **Unité** montre le nom de toutes les unités. Si un utilisateur choisit une unité d'une autre DR, les cartes restent vides : la DR fixée s'applique toujours.
