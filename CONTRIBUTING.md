# Règles concernant l'utilisation d'IA dans les contributions

Ce projet est réalisé dans un cadre pédagogique. L'objectif principal est que chaque contributeur comprenne, maîtrise et soit capable d'expliquer le code qu'il soumet.  
L'utilisation d'outils d'intelligence artificielle est autorisée uniquement dans des limites strictes.

---

## 1. Le code ne doit PAS être généré entièrement par IA
Les IA peuvent être utilisées pour :
- proposer des idées,
- expliquer du code,
- suggérer des améliorations,
- aider à déboguer,
- générer de petits extraits non critiques.

Elles ne doivent PAS être utilisées pour :
- écrire des fichiers entiers,
- produire des fonctionnalités complètes,
- restructurer massivement le projet,
- remplacer le travail personnel.

Toute contribution doit être compréhensible et explicable par son auteur.

En cas de suspicion de surutilisation de l'IA, le Git Master est susceptible d'interroger le contributeur à la réunion suivante.

---

## 2. Les commentaires existants ne doivent jamais être supprimés
Les commentaires font partie intégrante du travail pédagogique.

**Ils ne doivent pas être supprimés, réécrits ou modifiés par une IA.**

Toute suppression de commentaire — volontaire ou non — sera considérée comme une altération du travail pédagogique et entraînera un examen approfondi de la PR.

En cas de suppression injustifiée de commentaires :
- la PR sera immédiatement refusée,
- le contributeur devra restaurer manuellement les commentaires supprimés,
- le Git Master pourra demander des explications lors de la réunion suivante,
- des restrictions temporaires sur les contributions pourront être appliquées en cas de récidive.

Si un commentaire semble incorrect ou obsolète :
- le contributeur doit le signaler dans la PR,
- proposer une correction manuelle,
- attendre validation avant modification.

---

## 3. Transparence obligatoire
Toute PR doit inclure une section :

**"Utilisation d'IA : oui/non"**

Si oui :
- quel outil a été utilisé,
- pour quelle partie du code,
- dans quelle mesure (ex : “suggestion de correction”, “génération d’un snippet de 5 lignes”).

Les PR sans cette information pourront être refusées.

---

## 4. Vérification humaine obligatoire
Le contributeur doit :
- relire tout le code généré ou modifié,
- vérifier que les commentaires n’ont pas été supprimés,
- s’assurer que le code est cohérent avec le reste du projet,
- être capable d’expliquer chaque ligne lors d’une revue.

---

## 5. PR refusées automatiquement
Les PR seront refusées si :
- du code complet a été généré par IA,
- des commentaires existants ont été supprimés,
- le contributeur ne peut pas expliquer sa contribution,
- la section "Utilisation d'IA" est absente ou mensongère.

---

Merci de respecter ces règles afin de garantir un apprentissage réel et une qualité de code cohérente.
