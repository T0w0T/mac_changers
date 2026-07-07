# Change-MacAddress.ps1

Script PowerShell interactif pour modifier l’adresse MAC d’une carte réseau sous Windows 10/11.  
Il modifie la clé `NetworkAddress` dans le registre et redémarre l’interface pour appliquer le changement.

## 🚀 Utilisation

1. **Enregistrez** le script dans un fichier `Change-MacAddress.ps1`.
2. **Ouvrez PowerShell en tant qu’administrateur** (clic droit → *Exécuter en tant qu'administrateur*).
3. Si l’exécution de scripts est bloquée, autorisez-la temporairement :
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Exécutez le script :
   ```powershell
   .\Change-MacAddress.ps1
   ```
   Vous pourrez alors choisir une carte dans la liste et entrer la nouvelle adresse MAC.

### Avec paramètres

```powershell
# Changer la MAC de l'interface "Ethernet"
.\Change-MacAddress.ps1 -AdapterName "Ethernet" -MacAddress "00-11-22-33-44-55"

# Changer sur une interface Wi-Fi (contient "Wi-Fi")
.\Change-MacAddress.ps1 -AdapterName "Wi-Fi" -MacAddress "AABBCCDDEEFF"

# Restaurer la MAC d'origine
.\Change-MacAddress.ps1 -Reset
```

## ⚙️ Paramètres détaillés

| Paramètre      | Description |
|----------------|-------------|
| `-MacAddress`  | Adresse MAC souhaitée (12 caractères hexadécimaux, les `:` et `-` sont ignorés). |
| `-AdapterName` | Nom ou partie du nom de l’adaptateur cible. Exemple : `Ethernet`, `Wi-Fi`. |
| `-Reset`       | Supprime la personnalisation et restaure l’adresse MAC matérielle d’origine. |

Si `-MacAddress` est omis et que le script n’est pas en mode `-Reset`, il vous la demandera de manière interactive.

## 🔍 Fonctionnement

- Liste des adaptateurs physiques (`Get-NetAdapter`).
- Sélection par l’utilisateur.
- Le GUID de l’interface permet de retrouver la clé de registre :  
  `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\XXXX`
- La valeur `NetworkAddress` est créée, modifiée ou supprimée.
- L’interface est désactivée puis réactivée (Disable/Enable).

## ⚠️ Avertissements

- **Tous les pilotes ne supportent pas la modification logicielle de l’adresse MAC.**  
  Si la MAC reste inchangée après le redémarrage de l’interface, le matériel ou le pilote ne le permet probablement pas.
- Par défaut, le script ignore les adaptateurs **virtuels** (VMware, Hyper-V, VPN). Pour les inclure, retirez la condition `$_.Virtual -eq $false` dans le code.
- Une adresse MAC doit être unique sur un même réseau local. L’usurpation peut enfreindre les politiques de sécurité de votre organisation.

## 📄 Licence

Ce script est fourni sous licence **MIT**.  
Vous êtes libre de l’utiliser, de le modifier et de le distribuer, sous réserve d’inclure la notice de copyright d’origine.
