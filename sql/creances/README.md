# Balance des créances clients

`40_balance_creances_par_mois.sql` donne, pour chaque mois, les créances clients en **fin de mois**.

## Règles de calcul

- Créance d'une facture : **montant TTC** de la facture client validée, diminué de ce qui a été **lettré** dessus.
- Chaque règlement lettré (encaissement, avoir ou autre) diminue la créance à sa **date d'effet** :
  - date du règlement, si elle est **après** la date de facture ;
  - sinon **date de la facture**.
- Exemples :
  - facture d'avril payée en mai : en créance fin avril, soldée fin mai ;
  - facture d'avril annulée par un avoir en mai : en créance fin avril, soldée fin mai (colonne « avoirs ») ;
  - facture de mars payée d'avance en février : jamais en créance.
- Les paiements et avoirs **non lettrés** ne diminuent pas les créances.
- Famille client « client interne » (id 1005) exclue.

## Colonnes

`creances_debut_mois` + `facture_mois` − `encaisse_mois` − `avoirs_mois` − `autres_reglements_mois` = `creances_fin_mois`

« Autres règlements » : lettrages par écriture diverse (pertes, écarts de change…).

Le mois en cours s'arrête à aujourd'hui. Sa créance de fin de mois correspond donc au reste à payer actuel dans Odoo.

## Variables Metabase (facultatives)

- `annee` : **Nombre**, défaut **2026** (sans valeur : année en cours)
- `categorie` : **Texte** (classe client ; liste : question 22)
- `unite` : **Filtre de champ** → **Operating Unit → Name**

Visualisation : **Tableau**, ou **Lignes** avec X = mois et Y = creances_fin_mois.
