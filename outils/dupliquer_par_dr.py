#!/usr/bin/env python3
"""Copie un tableau de bord Metabase pour chaque direction régionale (DR).

Pour chaque DR :
  1. crée (ou réutilise) une collection « <préfixe><nom de la DR> » ;
  2. copie le tableau de bord modèle et ses questions dans cette collection ;
  3. dans chaque question copiée, écrit le nom de la DR en dur à la place de
     la variable {{dr}} et supprime cette variable ;
  4. retire du tableau de bord copié le filtre relié à {{dr}}.

L'utilisateur d'une DR, qui n'a que le droit de lecture, ne peut donc pas
changer de DR. Les droits des groupes sur les collections se règlent ensuite
dans Metabase (Admin → Autorisations → Collections).

Exemples :
  python3 outils/dupliquer_par_dr.py --email moi@exemple.com --tableau 5 --dr "DR Centre" --dr "DR Est"
  python3 outils/dupliquer_par_dr.py --email moi@exemple.com --tableau 5 --toutes-dr --base Odoo
  python3 outils/dupliquer_par_dr.py ... --essai      (affiche ce qui serait fait, sans rien modifier)

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

# [[ ... {{dr}} ... ]] : bloc facultatif Metabase contenant la variable dr
BLOC_DR = re.compile(r"\[\[([^\[\]]*?)\{\{\s*dr\s*\}\}([^\[\]]*?)\]\]")
VAR_DR = re.compile(r"\{\{\s*dr\s*\}\}")


def litteral_sql(texte):
    return "'" + texte.replace("'", "''") + "'"


def fixer_dr_dans_sql(sql, nom_dr):
    """Remplace chaque bloc [[ ... {{dr}} ... ]] par sa condition avec la DR en dur."""
    # Dans les commentaires « -- … », Metabase lit aussi {{dr}} : on le remplace par du texte.
    lignes = []
    for ligne in sql.split("\n"):
        pos = ligne.find("--")
        if pos >= 0:
            ligne = ligne[:pos] + VAR_DR.sub(f"dr (fixée : {nom_dr})", ligne[pos:])
        lignes.append(ligne)
    sql = "\n".join(lignes)
    nouveau = BLOC_DR.sub(lambda m: m.group(1) + litteral_sql(nom_dr) + m.group(2), sql)
    if VAR_DR.search(nouveau):
        raise ValueError("{{dr}} présent hors d'un bloc [[ ]] : remplacement refusé")
    return nouveau


def fixer_dr_dans_requete(objet, nom_dr):
    """Parcourt une dataset_query (ancien ou nouveau format) et fixe la DR.

    Renvoie (objet modifié, nombre de requêtes SQL modifiées)."""
    compte = 0

    def visiter(o):
        nonlocal compte
        if isinstance(o, dict):
            resultat = {}
            for cle, val in o.items():
                if cle == "template-tags" and isinstance(val, dict):
                    resultat[cle] = {k: visiter(v) for k, v in val.items() if k != "dr"}
                elif cle in ("query", "native") and isinstance(val, str) and VAR_DR.search(val):
                    resultat[cle] = fixer_dr_dans_sql(val, nom_dr)
                    compte += 1
                else:
                    resultat[cle] = visiter(val)
            return resultat
        if isinstance(o, list):
            return [visiter(v) for v in o]
        return o

    return visiter(objet), compte


def cible_est_dr(cible):
    """Vrai si une cible de filtre de tableau de bord vise la variable dr."""
    texte = json.dumps(cible)
    return '"template-tag", "dr"' in texte or '"template-tag","dr"' in texte


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


def lister_dr(mb, nom_base):
    bases = mb.appel("GET", "/api/database")
    bases = bases.get("data", bases) if isinstance(bases, dict) else bases
    base = next((b for b in bases if b["name"] == nom_base), None)
    if not base:
        raise SystemExit(f"Base « {nom_base} » introuvable dans Metabase.")
    rep = mb.appel("POST", "/api/dataset", {
        "database": base["id"], "type": "native",
        "native": {"query": "SELECT name FROM operating_unit WHERE is_dr = true ORDER BY name"}})
    return [ligne[0] for ligne in rep["data"]["rows"]]


def trouver_ou_creer_collection(mb, nom, parent_id):
    for c in mb.appel("GET", "/api/collection"):
        if c.get("name") == nom and c.get("archived") is not True and \
                (parent_id is None or (c.get("location") or "").rstrip("/").endswith(f"/{parent_id}")):
            print(f"  Collection existante : {nom} (id {c['id']})")
            return c["id"]
    print(f"  Création de la collection : {nom}")
    corps = {"name": nom, "color": "#509EE3"}
    if parent_id is not None:
        corps["parent_id"] = parent_id
    return mb.appel("POST", "/api/collection", corps, ecriture=True).get("id", "?")


ALERTES = []


def signaler(nom_carte, n):
    if n:
        print(f"    question « {nom_carte} » : DR fixée")
    else:
        print(f"    ⚠ question « {nom_carte} » : PAS de variable {{{{dr}}}}, elle affichera TOUTES les DR")
        ALERTES.append(nom_carte)


def dupliquer_pour_dr(mb, tableau_id, nom_dr, prefixe, parent_id):
    modele = mb.appel("GET", f"/api/dashboard/{tableau_id}")
    print(f"\n=== {nom_dr} ===")
    collection_id = trouver_ou_creer_collection(mb, f"{prefixe}{nom_dr}", parent_id)

    nom = f"{modele['name']} – {nom_dr}"
    print(f"  Copie du tableau de bord « {modele['name']} » → « {nom} »")
    copie = mb.appel("POST", f"/api/dashboard/{tableau_id}/copy",
                     {"name": nom, "collection_id": collection_id, "is_deep_copy": True},
                     ecriture=True)
    if mb.essai:
        cartes = [dc for dc in modele.get("dashcards", []) if dc.get("card_id")]
        for dc in cartes:
            carte = mb.appel("GET", f"/api/card/{dc['card_id']}")
            _, n = fixer_dr_dans_requete(carte["dataset_query"], nom_dr)
            signaler(carte["name"], n)
        return
    tableau = mb.appel("GET", f"/api/dashboard/{copie['id']}")

    # 1. Questions : DR en dur
    for dc in tableau.get("dashcards", []):
        if not dc.get("card_id"):
            continue
        carte = mb.appel("GET", f"/api/card/{dc['card_id']}")
        requete, n = fixer_dr_dans_requete(carte["dataset_query"], nom_dr)
        if n:
            mb.appel("PUT", f"/api/card/{carte['id']}", {"dataset_query": requete}, ecriture=True)
        signaler(carte["name"], n)

    # 2. Tableau de bord : retirer les filtres reliés à {{dr}}
    params_dr = {m["parameter_id"] for dc in tableau.get("dashcards", [])
                 for m in dc.get("parameter_mappings", []) if cible_est_dr(m.get("target"))}
    if params_dr:
        dashcards = []
        for dc in tableau["dashcards"]:
            dc = dict(dc)
            dc["parameter_mappings"] = [m for m in dc.get("parameter_mappings", [])
                                        if m["parameter_id"] not in params_dr]
            dashcards.append({k: dc[k] for k in dc if k in (
                "id", "card_id", "row", "col", "size_x", "size_y", "series",
                "parameter_mappings", "visualization_settings", "dashboard_tab_id")})
        parametres = [p for p in tableau.get("parameters", []) if p["id"] not in params_dr]
        mb.appel("PUT", f"/api/dashboard/{tableau['id']}",
                 {"parameters": parametres, "dashcards": dashcards}, ecriture=True)
        print(f"  Filtre DR retiré du tableau de bord ({len(params_dr)})")
    print(f"  Terminé : {mb.url}/dashboard/{tableau['id']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://localhost:3000", help="adresse de Metabase")
    ap.add_argument("--email", required=True, help="compte administrateur Metabase")
    ap.add_argument("--tableau", type=int, required=True, help="id du tableau de bord modèle (dans son adresse : /dashboard/5-…)")
    ap.add_argument("--dr", action="append", default=[], help="nom exact d'une DR (répétable)")
    ap.add_argument("--toutes-dr", action="store_true", help="toutes les DR (operating_unit.is_dr)")
    ap.add_argument("--base", default="Odoo", help="nom de la base Odoo dans Metabase (avec --toutes-dr)")
    ap.add_argument("--prefixe", default="", help="préfixe du nom des collections, ex. « Tableaux – »")
    ap.add_argument("--collection-parent", type=int, help="id de la collection où créer les collections DR")
    ap.add_argument("--essai", action="store_true", help="n'écrit rien, affiche ce qui serait fait")
    a = ap.parse_args()

    mb = Metabase(a.url, essai=a.essai)
    mb.connexion(a.email, os.environ.get("MB_PASSWORD") or getpass.getpass("Mot de passe Metabase : "))
    noms = list(a.dr)
    if a.toutes_dr:
        noms += [n for n in lister_dr(mb, a.base) if n not in noms]
    if not noms:
        sys.exit("Indiquez au moins une DR (--dr \"…\") ou --toutes-dr.")
    print("DR :", ", ".join(noms))
    for nom in noms:
        dupliquer_pour_dr(mb, a.tableau, nom, a.prefixe, a.collection_parent)
    if ALERTES:
        print("\n⚠ ATTENTION : ces questions n'ont pas de filtre {{dr}} et montrent toutes les DR :")
        for n in sorted(set(ALERTES)):
            print("   -", n)
        print("  Recollez-les depuis les fichiers du dépôt (qui contiennent {{dr}}), ou supprimez-les des copies.")


if __name__ == "__main__":
    main()
