# ALT — Roue RP et ciblage pour FiveM

**Créé par SYX** · Ressource FiveM standalone · Lua et NUI

ALT regroupe les gestes RP et les interactions de proximité sur une seule touche. Un appui court sur **Alt gauche** ouvre une roue noir, blanc et violet. Un maintien affiche un réticule de ciblage et les actions disponibles sur l’entité visée.

ALT fonctionne sans framework RP, sans `ox_lib`, sans `ox_target` et sans base de données.

## Fonctionnalités

- **Vêtements** · Retirer et remettre le haut, le pantalon, les chaussures, le chapeau et les lunettes. Les préréglages du haut, du pantalon et des chaussures sont prévus pour les personnages GTA freemode homme et femme.
- **Provisions** · Manger et boire avec des animations et des accessoires affichés localement. Chaque joueur reçoit par défaut cinq repas et cinq boissons par connexion.
- **Ciblage** · Ouvrir ou fermer les portes, le capot et le coffre d’un véhicule déverrouillé à portée, lorsque le client peut en prendre le contrôle. Tu peux aussi saluer un PNJ.
- **Intégration** · Ajouter tes propres interactions sur des véhicules, des peds ou des objets depuis une autre ressource.

## Installation

1. Télécharge les fichiers du dépôt.
2. Place-les dans `resources/ALT/`. Le fichier `fxmanifest.lua` doit se trouver directement dans le dossier `ALT`.
3. Ajoute cette ligne à ton `server.cfg` et démarre le serveur.

```cfg
ensure ALT
```

Si le serveur tourne déjà, exécute `refresh` puis `ensure ALT` dans la console serveur. Si tu renommes le dossier, reporte le nouveau nom dans `ensure` et dans les appels aux exports.

## Commandes en jeu

| Geste | Résultat |
| --- | --- |
| Appuyer brièvement sur **Alt gauche**, puis relâcher | Ouvrir la roue RP. Clique sur une action ou ferme la roue avec **Échap**. |
| Maintenir **Alt gauche** pendant 300 ms | Activer le ciblage et viser avec la caméra. |
| Tourner la **molette** pendant le maintien | Parcourir les interactions de la cible. |
| Appuyer sur **E** ou faire un **clic gauche** pendant le maintien | Exécuter l’interaction sélectionnée. Relâche Alt avant de cibler à nouveau. |
| Relâcher **Alt gauche** en mode ciblage | Fermer le ciblage. |

Le raccourci **ALT · Roue RP / Ciblage** est modifiable dans les paramètres de raccourcis FiveM.

## Configuration

Les réglages se trouvent dans [`config.lua`](config.lua).

| Réglage | Valeur par défaut | Effet |
| --- | --- | --- |
| `Config.Key` | `LMENU` | Touche proposée par défaut, soit **Alt gauche**. |
| `Config.HoldMs` | `300` | Durée de maintien en millisecondes pour activer le ciblage. |
| `Config.TargetDistance` | `3.0` | Distance maximale d’interaction. |
| `Config.Supplies` | `{ eat = 5, drink = 5 }` | Quantités de repas et de boissons par connexion. |
| `Config.Undress` | Préréglages GTA freemode | Variations affichées quand un vêtement est retiré. Ajuste-les si ton pack de vêtements les remplace. |

Les provisions sont comptées côté serveur. **Manger** et **Boire** déclenchent une animation et utilisent une provision.

## Ajouter une interaction de ciblage

Démarre ta ressource après `ALT`. L’exemple suivant ajoute une option **Examiner le distributeur** côté client et la réenregistre si ALT redémarre.

```lua
local function registerTarget()
    exports['ALT']:AddTargetOption({
        name = 'examiner_distributeur',
        label = 'Examiner le distributeur',
        kind = 'object',
        model = 'prop_vend_soda_01',
        distance = 2.0,
        event = 'mon_script:examinerDistributeur'
    })
end

AddEventHandler('mon_script:examinerDistributeur', function(entity)
    print(('Distributeur ciblé : %s'):format(entity))
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ALT' or resource == GetCurrentResourceName() then
        registerTarget()
    end
end)
```

`name`, `label` et `event` sont obligatoires. Les filtres `kind`, `model` et `distance` sont facultatifs. `kind` accepte `ped`, `vehicle` ou `object`. L’événement client reçoit l’entité ciblée.

Pour retirer l’option, appelle `exports['ALT']:RemoveTargetOption('examiner_distributeur')`. ALT retire aussi les options d’une ressource quand elle s’arrête.
