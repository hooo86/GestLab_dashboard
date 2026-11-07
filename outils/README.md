# Un tableau de bord par utilisateur, limité à ses unités opérationnelles

La version gratuite de Metabase ne sait pas limiter les lignes visibles selon l'utilisateur. Le script `dupliquer_tableau.py` crée donc **une copie du tableau de bord par utilisateur**, limitée aux **unités opérationnelles** qui lui sont attribuées dans **Odoo**. Un utilisateur peut avoir **plusieurs unités**.

Une DR est une unité comme les autres. Un utilisateur qui a l'unité « DR Centre » voit les factures de cette unité, pas celles de ses laboratoires. Pour qu'il les voie aussi, attribuez-lui ces unités dans Odoo.

## Comment ça marche

- Les unités de chaque utilisateur sont lues dans Odoo : fiche utilisateur → onglet **Unités opérationnelles**.
- L'utilisateur Metabase est retrouvé par son **e-mail** : le **login Odoo** s'il s'agit d'une adresse e-mail, sinon l'**e-mail de son contact** Odoo.
- Avec `--creer-comptes`, le script **crée les comptes Metabase manquants** (nom et e-mail repris d'Odoo).
- Chaque requête du dépôt (finance **et RH**) contient le repère `AND TRUE /* perimetre:… */`. Pour les RH, c'est l'unité de l'employé (`default_operating_unit_id`). Sur le tableau de bord modèle, il ne filtre rien. Dans chaque copie, le script le remplace par `… operating_unit_id IN (ses unités)`.
- Avec `--droits`, le script crée le groupe « Périmètre – Nom », y ajoute l'utilisateur et lui donne la **lecture seule** sur **sa** collection.

## 1. Préparer (une fois)

1. Sur la VM Metabase : `cd ~/GestLab_dashboard && git pull`.
2. Dans le tableau de bord modèle, **recollez chaque question** depuis le fichier du dépôt, pour que chacune contienne le repère `perimetre`.
3. Comptes Metabase : ajoutez `--creer-comptes` à la commande, et le script les crée. Vous pouvez aussi inviter chaque personne à la main (Admin → Personnes → Inviter) avec son login Odoo comme e-mail.
4. Réglez une fois les droits de base, dans **Admin → Autorisations** :
   - **Collections** : groupe **Tous les utilisateurs** = **Pas d'accès** sur « Nos analyses » et sur le modèle ;
   - **Données → Odoo** : groupe **Tous les utilisateurs** : **Voir les données = Peut voir**, **Créer des requêtes = Non**. C'est indispensable : sinon un utilisateur pourrait écrire son propre SQL et tout voir.

## 2. Lancer le script (sur la VM Metabase)

L'id du tableau de bord modèle se lit dans son adresse : `http://192.168.8.26:3000/dashboard/5-finance` → **5**.

Essai (ne modifie rien) :
```bash
python3 outils/dupliquer_tableau.py --email hocineinfo@gmail.com --tableau 5 --droits --essai
```
Lancement réel, pour tous les utilisateurs qui ont des unités, avec création des comptes :
```bash
python3 outils/dupliquer_tableau.py --email hocineinfo@gmail.com --tableau 5 --droits --creer-comptes
```

**Mots de passe des comptes créés** : sans serveur e-mail, Metabase n'envoie rien. Pour chaque personne : **Admin → Personnes** → « … » à côté de son nom → **Réinitialiser le mot de passe** → copiez le lien affiché et envoyez-le-lui.
Pour un ou quelques utilisateurs seulement :
```bash
python3 outils/dupliquer_tableau.py --email hocineinfo@gmail.com --tableau 5 --droits --utilisateur ali@lnhc.dz
```
Options : `--prefixe "Tableaux – "` (nom des collections), `--collection-parent 12`, `--base Odoo` (nom de la base Odoo dans Metabase).

Le script affiche :
- **« pas de compte Metabase »** : invitez la personne avec cet e-mail, puis relancez pour elle (`--utilisateur`) ;
- **« PAS de repère de périmètre »** : cette question montrerait toutes les unités. Recollez-la depuis le dépôt dans le modèle, puis refaites la copie.

## Quand les unités changent dans Odoo, ou après une modification du modèle

Chaque lancement crée une **nouvelle** copie. Mettez d'abord l'ancienne copie de la personne à la corbeille (dans sa collection), puis relancez le script pour elle :
```bash
python3 outils/dupliquer_tableau.py --email hocineinfo@gmail.com --tableau 5 --droits --utilisateur ali@lnhc.dz
```

## Limite

La liste déroulante du filtre **Unité** affiche le nom de toutes les unités. Si l'utilisateur choisit une unité qui n'est pas à lui, les cartes restent vides.
