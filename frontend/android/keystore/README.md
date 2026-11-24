# Android release signing (shared)

Committed files (push with the repo):

- `aips-release.jks` — release keystore  
- `../key.properties` — alias + passwords used by Gradle  

Any machine: `cd frontend && flutter build apk --release`  
Same signature → no package conflict on update.

After the **first** install of an APK signed with this keystore, uninstall any older debug-signed AIPS once.
