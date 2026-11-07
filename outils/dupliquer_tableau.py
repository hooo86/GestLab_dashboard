#!/usr/bin/env python3
"""Copie un tableau de bord Metabase pour chaque utilisateur, limité à SES unités opérationnelles.

Les unités de chaque utilisateur sont lues dans Odoo (onglet « Unités opérationnelles »
de la fiche utilisateur, champ operating_unit_ids). L'utilisateur Metabase est
retrouvé par son e-mail : le login Odoo s'il s'agit d'une adresse e-mail, sinon
l'e-mail de son contact Odoo. Avec --creer-comptes, les comptes manquants sont créés.

Pour chaque utilisateur :
  1. crée (ou réutilise) la collection « <préfixe><nom> » ;
  2. copie le tableau de bord modèle et ses questions dans cette collection ;
  3. dans chaque question copiée, remplace le repère  AND TRUE /* perimetre:xxx */
     par  AND xxx.operating_unit_id IN (<ses unités>) ;
  4. avec --droits : crée le groupe « Périmètre – <nom> », y ajoute l'utilisateur et
     lui donne la lecture seule sur sa collection.

Exemples :
  python3 outils/dupliquer_tableau.py --email admin@exemple.com --tableau 5 --essai
  python3 outils/dupliquer_tableau.py --email admin@exemple.com --tableau 5 --droits
  python3 outils/dupliquer_tableau.py --email admin@exemple.com --tableau 5 --utilisateur ali@lnhc.dz --droits

Mot de passe : demandé au lancement, ou variable d'environnement MB_PASSWORD.
Aucune dépendance : Python 3 standard.
"""
import argparse
import getpass
import json
import os
import re
import sys
import urllib.error
import urllib.request

# AND TRUE /* perimetre:alias */  ou  /* perimetre:alias.colonne */ (colonne par défaut : operating_unit_id)
REPERE = re.compile(r"AND TRUE /\* perimetre:(\w+)(?:\.(\w+))? \*/")

# Où Odoo range les unités de chaque utilisateur : lu dans la définition du champ
REQUETE_CHAMP_UNITES = """
SELECT relation_table, column1, column2
FROM ir_model_fields
WHERE model = 'res.users' AND name = '{champ}' AND ttype = 'many2many'
"""

REQUETE_UNITES_ODOO = """
SELECT lower(u.login)                       AS login,
       COALESCE(p.name, u.login)            AS nom,
       lower(p.email)                       AS email_contact,
       string_agg(ou.id::text, ',' ORDER BY ou.id)     AS ids,
       string_agg(ou.name, ', ' ORDER BY ou.name)      AS unites
FROM res_users u
JOIN res_partner p   ON p.id = u.partner_id
JOIN "{table}" r     ON r."{col_user}" = u.id
JOIN operating_unit ou ON ou.id = r."{col_unite}"
WHERE u.active
GROUP BY u.login, p.name, p.email
ORDER BY nom
"""


def fixer_perimetre_dans_sql(sql, ids):
    """Remplace chaque repère de périmètre par la liste des unités. Renvoie (sql, nb)."""
    liste = ", ".join(str(int(i)) for i in ids)
    return REPERE.subn(lambda m: f"AND {m.group(1)}.{m.group(2) or 'operating_unit_id'} IN ({liste})", sql)


def fixer_perimetre_dans_requete(objet, ids):
    """Parcourt une dataset_query (ancien ou nouveau format). Renvoie (objet, nb de repères)."""
    compte = 0

    def visiter(o):
        nonlocal compte
        if isinstance(o, dict):
            res = {}
            for cle, val in o.items():
                if cle in ("query", "native") and isinstance(val, str) and REPERE.search(val):
                    res[cle], n = fixer_perimetre_dans_sql(val, ids)
                    compte += n
                else:
                    res[cle] = visiter(val)
            return res
        if isinstance(o, list):
            return [visiter(v) for v in o]
        return o

    return visiter(objet), compte


class Metabase:
    def __init__(self, url, essai=False):
        self.url = url.rstrip("/")
        self.session = None
        self.essai = essai

    def appel(self, methode, chemin, corps=None, ecriture=False):
        if ecriture and self.essai:
            print(f"    [essai] {methode} {chemin}")
            return {}
        donnees = json.dumps(corps).encode() if corps is not None else None
        req = urllib.request.Request(self.url + chemin, data=donnees, method=methode)
        req.add_header("Content-Type", "application/json")
        if self.session:
            req.add_header("X-Metabase-Session", self.session)
        try:
            with urllib.request.urlopen(req, timeout=120) as rep:
                texte = rep.read().decode()
                return json.loads(texte) if texte else {}
        except urllib.error.HTTPError as e:
            raise SystemExit(f"Erreur {e.code} sur {methode} {chemin} : {e.read().decode()[:500]}")

    def connexion(self, email, mot_de_passe):
        self.session = self.appel("POST", "/api/session",
                                  {"username": email, "password": mot_de_passe})["id"]


def liste(rep):
    return rep.get("data", rep) if isinstance(rep, dict) else rep


def requete_odoo(mb, base_id, sql):
    rep = mb.appel("POST", "/api/dataset", {"database": base_id, "type": "native", "native": {"query": sql}})
    if rep.get("error"):
        raise SystemExit("Erreur dans Odoo : " + str(rep["error"])[:300])
    return rep["data"]["rows"]


def lire_unites_odoo(mb, nom_base, champ):
    base = next((b for b in liste(mb.appel("GET", "/api/database")) if b["name"] == nom_base), None)
    if not base:
        raise SystemExit(f"Base « {nom_base} » introuvable dans Metabase (option --base).")
    lignes = requete_odoo(mb, base["id"], REQUETE_CHAMP_UNITES.format(champ=champ))
    if not lignes:
        raise SystemExit(f"Champ « {champ} » (many2many) introuvable sur res.users. "
                         "Indiquez le bon nom avec --champ.")
    table, col_user, col_unite = lignes[0]
    for nom in (table, col_user, col_unite):
        if not re.fullmatch(r"\w+", nom or ""):
            raise SystemExit(f"Nom de table ou de colonne inattendu : {nom!r}")
    print(f"Unités des utilisateurs lues dans {table} ({col_user} → {col_unite})")
    sql = REQUETE_UNITES_ODOO.format(table=table, col_user=col_user, col_unite=col_unite)
    personnes = []
    for r in requete_odoo(mb, base["id"], sql):
        login, nom, email_contact, ids, unites = r
        # E-mail du compte Metabase : le login Odoo s'il ressemble à une adresse, sinon l'e-mail du contact
        email = login if "@" in (login or "") else (email_contact or "").strip()
        personnes.append({"login": login, "email": email, "nom": nom,
                          "ids": [int(x) for x in ids.split(",")], "unites": unites})
    return personnes


def trouver_ou_creer_collection(mb, nom, parent_id):
    for c in liste(mb.appel("GET", "/api/collection")):
        if c.get("name") == nom and not c.get("archived") and \
                (parent_id is None or (c.get("location") or "").rstrip("/").endswith(f"/{parent_id}")):
            print(f"  Collection existante : {nom}")
            return c["id"]
    print(f"  Création de la collection : {nom}")
    corps = {"name": nom, "color": "#509EE3"}
    if parent_id is not None:
        corps["parent_id"] = parent_id
    return mb.appel("POST", "/api/collection", corps, ecriture=True).get("id")


def donner_droits(mb, nom_groupe, user_id, collection_id):
    groupes = liste(mb.appel("GET", "/api/permissions/group"))
    groupe = next((g for g in groupes if g["name"] == nom_groupe), None)
    if groupe:
        gid = groupe["id"]
    else:
        print(f"  Création du groupe : {nom_groupe}")
        gid = mb.appel("POST", "/api/permissions/group", {"name": nom_groupe}, ecriture=True).get("id")
    membres = mb.appel("GET", "/api/permissions/membership")
    deja = gid is not None and isinstance(membres, dict) and \
        any(m.get("group_id") == gid for m in membres.get(str(user_id), []))
    if not deja:
        mb.appel("POST", "/api/permissions/membership", {"group_id": gid, "user_id": user_id}, ecriture=True)
    if collection_id is not None and gid is not None:
        graphe = mb.appel("GET", "/api/collection/graph")
        mb.appel("PUT", "/api/collection/graph",
                 {"revision": graphe["revision"], "groups": {str(gid): {str(collection_id): "read"}}},
                 ecriture=True)
    print(f"  Droits : groupe « {nom_groupe} » → lecture seule sur sa collection")


ALERTES = []


def creer_compte(mb, personne):
    morceaux = personne["nom"].split()
    corps = {"first_name": morceaux[0] if morceaux else personne["email"],
             "last_name": " ".join(morceaux[1:]) or "-",
             "email": personne["email"]}
    print(f"  Création du compte Metabase : {personne['email']}")
    return mb.appel("POST", "/api/user", corps, ecriture=True)


def copier_pour(mb, modele, personne, collection_id):
    nom = f"{modele['name']} – {personne['nom']}"
    print(f"  Copie du tableau de bord → « {nom} »")
    copie = mb.appel("POST", f"/api/dashboard/{modele['id']}/copy",
                     {"name": nom, "collection_id": collection_id, "is_deep_copy": True}, ecriture=True)
    tableau = modele if mb.essai else mb.appel("GET", f"/api/dashboard/{copie['id']}")
    for dc in tableau.get("dashcards", []):
        if not dc.get("card_id"):
            continue
        carte = mb.appel("GET", f"/api/card/{dc['card_id']}")
        requete, n = fixer_perimetre_dans_requete(carte["dataset_query"], personne["ids"])
        if n:
            mb.appel("PUT", f"/api/card/{carte['id']}", {"dataset_query": requete}, ecriture=True)
            print(f"    question « {carte['name']} » : limitée à ses unités")
        else:
            print(f"    ⚠ question « {carte['name']} » : PAS de repère de périmètre, elle montre TOUTES les unités")
            ALERTES.append(carte["name"])
    if not mb.essai:
        print(f"  Terminé : {mb.url}/dashboard/{tableau['id']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://localhost:3000", help="adresse de Metabase")
    ap.add_argument("--email", required=True, help="compte administrateur Metabase")
    ap.add_argument("--tableau", type=int, required=True, help="id du tableau de bord modèle (adresse /dashboard/5-…)")
    ap.add_argument("--utilisateur", action="append", default=[], help="login Odoo à traiter (répétable) ; par défaut : tous")
    ap.add_argument("--base", default="Odoo", help="nom de la base Odoo dans Metabase")
    ap.add_argument("--champ", default="operating_unit_ids", help="champ Odoo des unités de l'utilisateur (res.users)")
    ap.add_argument("--prefixe", default="Tableaux – ", help="préfixe du nom des collections")
    ap.add_argument("--collection-parent", type=int, help="id de la collection où créer les collections")
    ap.add_argument("--droits", action="store_true", help="créer le groupe et donner la lecture sur la collection")
    ap.add_argument("--creer-comptes", action="store_true", help="créer dans Metabase les comptes manquants")
    ap.add_argument("--essai", action="store_true", help="n'écrit rien, affiche ce qui serait fait")
    a = ap.parse_args()

    mb = Metabase(a.url, essai=a.essai)
    mb.connexion(a.email, os.environ.get("MB_PASSWORD") or getpass.getpass("Mot de passe Metabase : "))

    personnes = lire_unites_odoo(mb, a.base, a.champ)
    if a.utilisateur:
        voulus = {u.lower() for u in a.utilisateur}
        personnes = [p for p in personnes if p["login"] in voulus]
    comptes = {u["email"].lower(): u for u in liste(mb.appel("GET", "/api/user"))}
    modele = mb.appel("GET", f"/api/dashboard/{a.tableau}")
    print(f"Modèle : « {modele['name']} » – {len(personnes)} utilisateur(s) Odoo avec des unités")

    sans_compte, crees = [], []
    for p in personnes:
        print(f"\n=== {p['nom']} ({p['email'] or p['login']}) : {p['unites']} ===")
        if not p["email"]:
            print("  ⚠ pas d'adresse e-mail (ni login, ni contact Odoo) : ignoré")
            sans_compte.append(p["login"])
            continue
        compte = comptes.get(p["email"])
        if not compte and a.creer_comptes:
            compte = creer_compte(mb, p) or {"id": None}
            crees.append(p["email"])
        if not compte:
            print("  ⚠ pas de compte Metabase avec cet e-mail : ignoré (option --creer-comptes)")
            sans_compte.append(p["email"])
            continue
        collection_id = trouver_ou_creer_collection(mb, f"{a.prefixe}{p['nom']}", a.collection_parent)
        copier_pour(mb, modele, p, collection_id)
        if a.droits and compte.get("id") is not None:
            donner_droits(mb, f"Périmètre – {p['nom']}", compte["id"], collection_id)
        elif a.droits:
            print("    [essai] droits donnés après création du compte")

    if crees:
        print("\nComptes créés (" + str(len(crees)) + ") : chaque personne doit choisir son mot de passe.")
        print("  Admin → Personnes → « … » à côté du nom → Réinitialiser le mot de passe → copier le lien et le lui envoyer.")
    if sans_compte:
        print("\nSans compte Metabase (invitez-les avec cet e-mail puis relancez) :", ", ".join(sans_compte))
    if ALERTES:
        print("\n⚠ Questions sans repère de périmètre (elles montrent toutes les unités) :")
        for n in sorted(set(ALERTES)):
            print("   -", n)
        print("  Recollez-les depuis les fichiers du dépôt, puis relancez.")


if __name__ == "__main__":
    main()
