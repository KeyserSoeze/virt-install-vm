# virt-install-vm

Dieses Bash-Skript vereinfacht die automatische Installation ähnlicher VMs über die libvirt-API:

- Es ist ein Wrapper um `virt-install`.
- Es generiert preseed Dateien auf Basis von Vorlagen und Parametern, ermöglicht LATE_COMMANDs im Debian-Installer sowie das Ausrollen zusätzlicher Dateien (z.B. SSH-Keys) via initrd.
- Alle für die Erzeugung der VMs nötigen Configs können als einfache Text-Dateien in einem Verzeichnis je Datencenter/Provider/Projekt abgelegt und unter Versionsverwaltung gestellt werden.
- Es bietet Einsprung-Punkte für Werkzeuge zur weiteren Konfiguarion (z.B. Ansible).
- Damit ermöglicht es eine Teil- oder Voll-automatische Provisioning-/Deployment-Chain (automatische Re-Installation einer minimalen OS-Umgebung) sowie gleichzeitig Doku sowohl von VM-Eigenschaften als auch OS-Install-Einstellungen.

*Hinweis: Diese Skript wurde bisher ausführlich nur mit Debian 9 getestet.*

## System-Anforderungen

Zwingend wird benötigt (das Skript prüft darauf und bricht sonst ab):

- Der Befehl `virt-install` aus dem Paket `virtinst` (`sudo apt install virtinst`)

Optional wird benötigt (das Skript prüft darauf und gibt sonst eine Warnung aus):

- Für interaktive Passwort-Hash-Generierung: Der Befehl `mkpasswd` aus dem Paket `whois` (`sudo apt install whois`)
- Für die --legacy Option (als Bugfix bei alten libvirt Versionen): Der Befehl `virsh` aus dem Paket `libvirt-bin` (`sudo apt install libvirt-bin`)

Möglicherweise wird benötigt (das Skript prüft darauf und gibt sonst eine Warnung aus):

- Das Paket `gawk`.
  - Das Skript wurde bisher nur ausführlich mit `awk` aus dem Paket `gawk` getestet.
  - Ob die `awk` Version aus dem Paket `mawk` (ebenfalls Teil von Debian Base System) auch läuft, ist noch unklar.
  - Sollte es zu Problemen bei der Erzeugung der Preseed-Datei kommen, muss `gawk` nachinstalliert werden (`sudo apt install gawk`).

Ungeprüft (da Teil von Debian Base System) wird vorausgesetzt, dass folgende Pakete und diese darin enthaltenen Befehle vorhanden sind:

- bash: bash
- coreutils: cp, rm, basename, mktemp, date, sleep
- grep: grep
- tar: tar
- util-linux: getopt, more

## Installation

Die Installation kann systemweit (s.u.) oder für einen einzelnen Nutzer erfolgen. Dafür wird dieses Repo in ein lokales Verzeichnis kopiert und ein Symlink in einem Verzeichnis im `$PATH` auf das Bash-Skript `virt-install-vm` angelegt.

Für systemweite Installation empfiehlt sich zur Installation das Verzeichnis `/opt/virt-install-vm/` und ein Symlink in `/usr/local/bin/`:

    sudo git clone https://github.com/KeyserSoeze/virt-install-vm /opt/virt-install-vm
    sudo ln -s /opt/virt-install-vm/virt-install-vm /usr/local/bin/virt-install-vm

Schließlich sollte noch `.virt-install-vm.cfg` nach `~/.virt-install-vm.cfg` kopiert und dort mindestens `INIT_DIR_SRC` auf das gewählte Installations-Verzeichnis gesetzt werden. Dadurch wird es möglich, das aktuelle Verzeichnis mit Vorlage-Dateien zu füllen, durch Aufruf von `virt-install-vm --init-dir`.

## Hintergrund: Ablauf eines Deployments mit virt-install-vm

Bei der Installation einer VM durch Aufruf von `virt-install-vm` geschieht grob Folgendes:

- `virt-install-vm` erzeugt aus den Config-Dateien und Parametern die Dateien `preseed.cfg` und `preseed.tar` sowie einen Aufruf für `virt-install`.
- `virt-install` erzeugt auf dem Hypervisor eine VM mit den Eigentschaften (RAM, etc.) entsprechend seines Aufrufes und startet diese VM mit Kernel und initrd des Debian-Netinstallers. Dabei werden `preseed.cfg` und `preseed.tar` in die initrd eingefügt.
- In der VM startet der Debian-Installer (d-i) und nutzt zur automatischen Beantwortung der Fragen die Werte aus `preseed.cfg`.
- Am Ende der Installation führt der d-i das `LATECOMMAND` aus, darüber können weitere Anpassungen der VM (z.B. Kopieren eines SSH-Key aus `preseed.tar` auf die VM) durchgeführt werden.
- Die VM wird neu gestartet und `virt-install` meldet den Abschluss der Installation.
- Zum Schluss führt `virt-install-vm` das `FINISHED_CMD` aus, um so bei Bedarf weitere Einstellungen/Installationen in der VM mit Konfigurationsverwaltungs-Werkzeugen wie Ansible vorzunehmen.

## Variablen Precedence und Config-Dateien

Einige Variablen haben im Skript Default-Werte und das Skript versucht `VM_NAME` automatisch aus dem Dateinamen (ohne Pfad und Endung) des ersten non-option Parameters zu ermitteln. Diese Werte haben die niedrigste Priorität und werden von allen folgenden Dateien und Parametern überschrieben.

Im Anschluss liest das Skript in dieser Reihenfolge diese Config-Dateien ein (so vorhanden), wobei gleiche Variablen aus früheren Dateien durch solche aus späteren Dateien überschrieben werden:

- `$HOME/.virt-install-vm.cfg`
- `virt-install-vm.cfg` (im aktuellen Verzeichnis)
- `example.vm` (oder welche VM-Config-Datei sonst dem Skript als erster non-option Parameter übergeben wird)

Dabei ist darauf zu achten, dass bei späterer Änderung solcher Variablen, die als Werte für andere Variablen verwendet werden, diese anderen Variablen später auch nochmal gesetzt werden müssen (wurde z.B. `INJECT_SSH_PUBKEY` in `virt-install-vm.cfg` gesetzt und wird später in `example.vm` überschrieben, so muss auch `INJECT_FILES` dort nochmal neu gesetzt werden, damit der neue `INJECT_SSH_PUBKEY` verwendet wird).

Höchste Priorität haben Kommandozeilen-Argumente. Diese können nicht (bis auf `--dry-run`, `--legacy` und `--quiet`) durch Werte in Config-Dateien überschrieben werden.

## Variablen im Skript und den Demo-Dateien

Es folgen alle Variablen mit ihren Default-Werten im Skript und in den Demo-Dateien sowie kurze Erläuterungen:

    DRY_RUN=false
    QUIET=false
    LEGACY=false
    INIT_DIR_SRC=
    INIT_DIR_EXCLUDE="virt-install-vm|.virt-install-vm.cfg|README.md|LICENSE|.git|.gitignore"

Diese Variablen steuern grundsätzliche Arbeitsweisen des Skripts und haben die angegebenen Default-Werte, so diese nicht durch Kommandozeilen-Parameter oder Config-Dateien überschrieben werden.

    VIRSH_URI=
    VM_NAME=
    VM_RAM=
    VM_NET=
    VM_NET_MODEL=
    VM_NET2=
    VM_DISK_NAME=
    VM_DISK_POOL=
    VM_DISK_VG=
    VM_DISK_SIZE=
    VM_DISK_MODEL=
    VM_GRAPHICS=
    VM_ADD_OPTIONS=
    VM_OS_TYPE=
    VM_OS_VARIANT=
    VM_INSTALL_SRC_LOCATION=
    VM_EXTRA_ARGS=

Diese Variablen werden genutzt, um den Aufruf von `virt-install` zu erzeugen. Sie haben keine Default-Werte und beschreiben hauptsächlich Hardware-Eigenschaften der VM (aber z.B. auch die URL des Netinstallers oder Verbindungsparameter zum Hypervisor).

    PRESEED_TEMPLATE=
    INJECT_SSH_PUBKEY=
    INJECT_POSTINSTALL=
    INJECT_FILES=

Diese Variablen steuern das Einfügen von Dateien in die initrd des Netinstallers. Also das Template zur Erzeugung von `preseed.cfg` sowie welche Dateien in `preseed.tar` gepackt werden.

    # PRESEED_IP4_ADDR={{IP4_ADDR}}
    # PRESEED_IP6_PREFIX={{IP6_PREFIX}}
    # PRESEED_IP6_SUFFIX={{IP6_SUFFIX}}
    # PRESEED_IP_NETMASK={{IP_NETMASK}}
    # PRESEED_IP_GW={{IP_GW}}
    # PRESEED_HOSTNAME={{HOSTNAME}}
    # PRESEED_DOMAIN={{DOMAIN}}
    # PRESEED_USERFULLNAME={{USERFULLNAME}}
    # PRESEED_USERNAME={{USERNAME}}
    # PRESEED_PWDHASH={{PWDHASH}}
    # PRESEED_USER_SPECIAL={{USER_SPECIAL}}
    # PRESEED_TASKSEL={{TASKSEL}}
    # PRESEED_PACKAGES={{PACKAGES}}
    # PRESEED_PACKAGES_DEBCONF={{PACKAGES_DEBCONF}}
    # PRESEED_LATECOMMAND={{LATECOMMAND}}

Alle Variablen mit dem Prefix `PRESEED_` sind nicht fest im Skript eingestellt. Sie können beliebig selbst erstellt werden. Ihre Werte werden bei der Erzeugung von `preseed.cfg` aus dem Template an den Stellen eingefügt, an denen im Template ihr Suffix in doppelten geschweiften Klammern auftaucht.
Eine Liste wie diese kann zu Debug-/Test-Zwecken kommentiert an den Anfang des Templates gestellt werden, um diese Ersetzung zu überprüfen.
Die hier aufgezälten Variablen werden im mitgelieferten Demo-Template `example-stretch-hetzner.preseed` genutzt und durch die mitgelieferten Demo-Config-Dateien `.virt-install-vm.cfg`, `virt-install-vm.cfg` und `example-short.vm` gefüllt.

    FINISHED_CMD=

Diese Variable gibt den Befehl oder die Befehle an, welche nach Abschluss der VM-Installation lokal ausgeführt werden sollen, etwa um mit einem Konfigurationsverwaltungs-Werkzeug wie Ansible weitere Anpassungen in der VM vorzunehmen.

## Konfiguration und Anpassung an die eigene Infrastruktur

Die mitgelieferten Demo-Dateien `.virt-install-vm.cfg`, `virt-install-vm.cfg`, `example-short.vm`, `example-long.vm`, `example-stretch-hetzner.preseed` und `example-post-install.sh` stellen einen guten Ausgangspunkt für die Anpassung an die eigene Infrastruktur dar.
`.virt-install-vm.cfg` sollte bei der Installation nach $HOME kopiert und angepasst werden, die anderen Dateien werden bei einem Aufruf von `virt-install-vm --init-dir` ins aktuelle Verzeichnis kopiert.

Es empfiehlt sich je Provider oder Hypervisor ein Config-Verzeichnis zu verwenden. In diesem Verzeichnis können die gemeinsamen Einstellung für alle VMs dieser Gruppe (z.B. Gateway, IPv6-Prefix oder apt-mirror) in einer `virt-install-vm.cfg` sowie einem oder ggf. mehreren Preseed-Templates festgelegt werden. Für jede VM in dieser Gruppe kann eine Datei VM_NAME.vm angelegt werden, in der dann nur noch die wenigen unterschiedlichen Einstellungen (z.B. IPv6-Suffix, RAM oder `FINISHED_CMD`) festgelegt werden müssen.

Die mitgelieferten Demo-Dateien sind bei einem installierten libvirt-KVM-Host beim Provider Hetzner lauffähig - in dieser konkreten Umgebung müssten nur noch die IP- & Netzwerk-Konfiguration, Domain und VM_DISK_POOL angepasst sowie DRY_RUN auskommentiert werden. In anderen Umgebungen müssen mehr Anpassungen an den Demo-Dateien vorgenommen werden. Es empfielt sich, das Verzeichnis mit den (an die eigene Infrastruktur angepassten) Config-Dateien unter Versionsverwaltung zu stellen.

## Beispiele

Es folgen einige Beispiel-Aufrufe von `virt-install-vm`:

    virt-install-vm -h

Anzeige der Hilfe für Kommandozeilen-Parameter.

    virt-install-vm --init-dir

Vorlage-Dateien aus `INIT_DIR_SRC` in das aktuelle Verzeichnis kopieren.

    virt-install-vm --dry-run example.vm

Probelauf der Installation einer VM entsprechend der Einstellungen in `example.vm` (und ggf. anderer gefundener Config-Dateien s.o.) durchführen. Bei diesem Probelauf werden nur die Config-Dateien und Aufrufe generiert und angezeigt, aber die Installation nicht durchgeführt.

    virt-install-vm example.vm

Installation einer VM entsprechend der Einstellungen in `example.vm` (und ggf. anderer gefundener Config-Dateien s.o.) durchführen.

    virt-install-vm -r 512 example.vm

Installation einer VM entsprechend der Einstellungen in `example.vm` (und ggf. anderer gefundener Config-Dateien s.o.), jedoch mit 512MB RAM, durchführen.

## Lizenz

GPL-3.0
