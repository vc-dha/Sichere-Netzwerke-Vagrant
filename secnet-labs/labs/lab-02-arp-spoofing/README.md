# Sichere Netzwerke – Vagrant-Labs (Windows, Linux, Mac)

Alternative zu den Docker-Compose-Labs aus dem Original-Repository für alle,
die lieber mit echten VMs statt Containern arbeiten (realistischeres
Netzwerkverhalten, z. B. bei ARP-Spoofing) oder kein Docker Desktop
nutzen wollen/können.

**Läuft auf Windows, Linux und macOS** über Vagrant + VirtualBox.
Windows-Nutzer mit Hyper-V können alternativ den nativen Hyper-V-Provider
verwenden – siehe unten.

---

## Welchen Provider soll ich nehmen?

| Provider | Plattform | Voraussetzung | Empfehlung |
|---|---|---|---|
| **VirtualBox** | Windows, Linux, macOS | Kostenlos, keine Windows-Edition-Pflicht | ✅ **Standard-Empfehlung** |
| Hyper-V | nur Windows | Windows **Pro/Education/Enterprise** | Nur falls bereits eingerichtet/genutzt |

Falls unsicher: **VirtualBox nehmen.** Es läuft überall und braucht keine
besondere Windows-Version.

---

## Schnellstart in 4 Schritten

### 1. VirtualBox installieren

👉 https://www.virtualbox.org/wiki/Downloads

Installer für deine Plattform herunterladen und ausführen. Keine
Zusatzkonfiguration nötig.

> **Windows mit Hyper-V:** Falls du Hyper-V bereits aktiviert hast, kann es
> mit VirtualBox in Konflikt stehen. Entweder Hyper-V deaktivieren, oder
> direkt den Hyper-V-Provider nutzen (siehe Abschnitt "Alternative:
> Hyper-V" unten).

### 2. Vagrant + Packer installieren

- Vagrant: https://developer.hashicorp.com/vagrant/downloads
- Packer: https://developer.hashicorp.com/packer/downloads

Für dein Betriebssystem herunterladen und installieren. Kontrolle in einem
neuen Terminal:

```bash
vagrant --version
packer --version
```

> **Windows:** Packer wird als reine `.exe` ohne Installer ausgeliefert und
> landet damit nicht automatisch im `PATH`. Falls `packer --version` mit
> "not recognized"/"nicht gefunden" abbricht, die `.exe` in einen festen
> Ordner legen (z. B. `C:\Tools\packer\`) und diesen Ordner manuell zum
> `PATH` hinzufügen:
>
> ```powershell
> [Environment]::SetEnvironmentVariable(
>   "Path",
>   $env:Path + ";C:\Tools\packer",
>   "User"
> )
> ```
>
> Danach ein **neues** Terminal öffnen, damit die Änderung greift.

### 3. Basis-Box bauen (einmalig, ca. 20–30 Minuten)

```bash
cd packer
packer init .
packer build secnet-virtualbox.pkr.hcl
```

Danach die fertige Box bei Vagrant registrieren:

```bash
vagrant box add ubuntu-secnet-virtualbox ./ubuntu-secnet-virtualbox.box
```

Kontrolle:

```bash
vagrant box list
```

Sollte `ubuntu-secnet-virtualbox (virtualbox, 0)` zeigen.

> **Warum selbst bauen statt fertige Box laden?** Kein Download von einer
> fremden Quelle nötig – du weißt genau, was in deiner Box steckt, und sie
> bleibt bei dir lokal, ohne Cloud-Abhängigkeit.

### 4. Ein Lab starten

Jedes Lab braucht einmalig ein eigenes, isoliertes internes Netzwerk – das
übernimmt VirtualBox automatisch beim ersten `vagrant up`, kein manueller
Schritt nötig (anders als bei Hyper-V, siehe unten).

```bash
cd labs/lab-01-mitm
vagrant up --provider=virtualbox
```

Beenden und komplett aufräumen:

```bash
vagrant destroy -f
```

---

## Alternative: Hyper-V (nur Windows Pro/Education/Enterprise)

Falls du lieber den nativen Windows-Hyper-V-Provider nutzt:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
# Neustart erforderlich
```

Box bauen:

```powershell
cd packer
packer build secnet-hyperv.pkr.hcl
vagrant box add ubuntu-secnet-hyperv .\ubuntu-secnet-hyperv.box
```

Vor dem ersten `vagrant up` pro Lab **einmalig** einen Switch anlegen
(Name muss zum Lab passen, siehe Tabelle unten):

```powershell
New-VMSwitch -Name "lab01-net" -SwitchType Internal
```

Danach:

```powershell
cd labs\lab-01-mitm
vagrant up --provider=hyperv
```

---

## Verfügbare Labs

| # | Ordner | Titel | Status | Netz (VirtualBox/Hyper-V) |
|---|---|---|---|---|
| 01 | `labs/lab-01-mitm` | Man-in-the-Middle | ✅ fertig | `lab01-net` |
| 02 | `labs/lab-02-arp-spoofing` | ARP Spoofing | ✅ fertig | `lab02-net` |
| 03 | `labs/lab-03-tls-analyse` | TLS-Analyse | 🚧 in Arbeit | `lab03-net` |
| 04 | – | BGP-Verkehr-Analyse | – läuft ohne Docker/VMs, siehe Original-Repo | – |
| 05 | `labs/lab-05-dns-poisoning` | DNS Poisoning | 🚧 in Arbeit | `lab05-net` |

Jedes Vagrantfile funktioniert mit **beiden** Providern – einfach beim
Start mit `--provider=virtualbox` oder `--provider=hyperv` wählen (oder
weglassen, dann fragt Vagrant nach).

---

## Lab 01 – Man-in-the-Middle

**Netzwerk:** `172.30.0.0/24`

| VM | IP | Rolle |
|---|---|---|
| victim | 172.30.0.10 | Opfer, ruft Server auf |
| attacker | 172.30.0.99 | Sitzt in der Mitte, IP-Forwarding aktiv |
| server | 172.30.0.20 | HTTP-Server mit "vertraulichen" Daten |

```bash
cd labs/lab-01-mitm
vagrant up --provider=virtualbox
```

**Terminals öffnen:**

```bash
vagrant ssh victim
vagrant ssh attacker
vagrant ssh server
```

`victim` und `server` sind hier bewusst statisch so konfiguriert, dass
ihr gesamter gegenseitiger Traffic über `attacker` geleitet wird
(symmetrische Routen in beide Richtungen) – das simuliert die MITM-Position,
ohne dass zusätzliches ARP-Spoofing nötig ist. (Eine Variante mit echtem
ARP-Spoofing wie in Lab 02 ist ebenfalls möglich, aber empfindlicher
gegenüber doppelten/verwaisten virtuellen Netzwerk-Adaptern.)

**Mitschnitt starten (im attacker-Terminal, zuerst):**

```bash
# Interface mit "ip a" pruefen, meist enp0sX statt eth1
sudo tcpdump -i enp0s9 -n -A tcp port 8080 -w /tmp/capture.pcap
```

**Testen (im victim-Terminal, danach):**

```bash
curl http://172.30.0.20:8080/
```

**Auswerten (im attacker-Terminal, nach `Strg+C` auf tcpdump):**

```bash
tcpdump -r /tmp/capture.pcap -A -n | less
```

Zu sehen: der komplette `GET`-Request und die HTTP-Antwort im Klartext,
inklusive der "vertraulichen" Zugangsdaten – mitgeschnitten an einer
Verbindung, die eigentlich nur zwischen `victim` und `server`
stattfinden sollte.

> **Reihenfolge wichtig:** tcpdump immer *vor* dem `curl`-Aufruf starten,
> sonst verpasst man den Anfang der Verbindung (Request landet dann
> außerhalb des Mitschnitts).

---

## Lab 02 – ARP Spoofing

**Netzwerk:** `10.99.99.0/24`

| VM | IP | Rolle |
|---|---|---|
| alice | 10.99.99.10 | Opfer, generiert automatisch Traffic |
| gateway | 10.99.99.1 | "Firmen-Intranet" (HTTP, Port 80) |
| mallory | 10.99.99.99 | Angreifer (ettercap vorinstalliert) |

```bash
cd labs/lab-02-arp-spoofing
vagrant up --provider=virtualbox
```

**Angriff starten (Terminal 1, mallory):**

```bash
vagrant ssh mallory
```

```bash
# Interface vorher mit "ip a" pruefen - unter VirtualBox mit Ubuntu 26.04
# heisst es meist enp0s8, NICHT eth1 (der Docker-Guide nutzt eth0 - das
# gilt nur fuer die Container-Variante, nicht fuer VirtualBox/Hyper-V)
sudo ettercap -T -i enp0s8 -M arp:remote /10.99.99.10// /10.99.99.1//
```

Sobald das läuft, im ettercap-Output live mitlesen: kompletter HTTP-Request
und -Response im Klartext, inklusive `Benutzername: admin` /
`Passwort: SuperGeheim123` aus dem Traffic-Generator auf alice.

**ARP-Cache auf alice live beobachten (Terminal 2, alice):**

```bash
vagrant ssh alice
```

```bash
watch -n 2 "arp -n"
```

Vor dem ettercap-Start steht bei `10.99.99.1` die echte MAC von gateway.
Kurz nach dem Start ändert sich der Eintrag auf die MAC von mallory -
das ist der eigentliche Vergiftungs-Nachweis. alice merkt selbst nichts
davon, die Verbindung bleibt bestehen.

**ARP-Pakete mitschneiden (Terminal 3, ebenfalls auf alice):**

```bash
sudo tcpdump -i enp0s8 -n arp
```

Zeigt die gefälschten "ARP is-at"-Antworten, die mallory laufend
verschickt, um den Cache-Eintrag frisch zu halten.

---

## Häufige Probleme

**Beim ersten `vagrant up` wird ein Provider abgefragt / falscher Provider gewählt:**
Explizit angeben: `vagrant up --provider=virtualbox`. Dauerhaft festlegen
mit der Umgebungsvariable `VAGRANT_DEFAULT_PROVIDER=virtualbox`.

**VirtualBox und Hyper-V gleichzeitig auf Windows:**
Beide können sich gegenseitig blockieren (unterschiedliche
Virtualisierungstechnologien im Kernel). Für VirtualBox muss Hyper-V
deaktiviert sein (`bcdedit /set hypervisorlaunchtype off`, dann
Neustart) – oder direkt konsequent den Hyper-V-Provider nutzen.

**Netzwerk-Interface heißt nicht `eth1`:**
Je nach VirtualBox-/Hyper-V-Version und Ubuntu-Netzwerk-Namensschema kann
das Interface anders heißen. Unter VirtualBox mit Ubuntu 26.04 heißt es
meist `enp0s8` oder `enp0s9` (statt `eth1`). In der VM mit `ip a` prüfen,
welches Interface die im Lab angegebene IP trägt, und den Befehl
entsprechend anpassen. `ip route get <ziel-ip>` zeigt zusätzlich direkt,
über welches Interface eine bestimmte Verbindung tatsächlich läuft.

**`vagrant up` bricht mit Authentifizierungsfehlern ab:**
Meist eine veraltete Box-Version registriert. Box komplett neu hinzufügen:

```bash
vagrant box remove ubuntu-secnet-virtualbox
vagrant box add ubuntu-secnet-virtualbox ./ubuntu-secnet-virtualbox.box
```

**Packer-Build für die Basis-Box hängt bei "waiting for cloud-init..." und
landet dann in der interaktiven Sprachauswahl statt im Autoinstall:**
Im `http`-Ordner des jeweiligen Providers (`packer/virtualbox/http/` bzw.
`packer/hyperv/http/`) muss neben `user-data` **immer auch eine leere
Datei `meta-data`** liegen. Ohne sie kann cloud-init den
`nocloud-net`-Datasource nicht vollständig laden und fällt auf die
interaktive Installation zurück.

```bash
# im jeweiligen http-Ordner
touch meta-data
```

**Mehrere Netzwerk-Interfaces mit derselben IP in einer VM (`ip a` zeigt
z. B. `172.30.0.99` gleich auf mehreren `enp0sX`-Interfaces) und
`tcpdump` sieht trotzdem keinen Traffic:**
Das sind Überbleibsel aus vorherigen, nicht sauber beendeten
`vagrant up`-Läufen (z. B. nach einem abgebrochenen Build oder mehrfachen
Providerwechseln). Am zuverlässigsten hilft ein sauberer Neustart:

```bash
vagrant destroy -f
vagrant up --provider=virtualbox
```

Danach sollte jede VM pro Lab-Netzwerk nur noch **ein** privates
Interface mit der erwarteten IP haben.

**Mehrere Labs gleichzeitig laufen lassen:**
Kein Problem – jedes Lab hat sein eigenes isoliertes Netzwerk, sie
beeinflussen sich nicht gegenseitig. Achte nur auf genug freien RAM
(jede VM 512 MB–1 GB, je nach Lab).

---

## Wichtiger Sicherheitshinweis

Diese Boxen verwenden bewusst schwache/Standard-Zugangsdaten
(`vagrant`/`vagrant`, NOPASSWD-sudo, Standard-Vagrant-SSH-Key) sowie
absichtlich verwundbare Demo-Anwendungen (Klartext-HTTP, ungeschützte
ARP-Kommunikation). Das ist **ausschließlich für isolierte, lokale
Lab-Umgebungen** gedacht. Niemals diese Boxen oder Konfigurationen in
einem produktiven, internetzugänglichen oder gemeinsam genutzten
Netzwerk verwenden.

---

## Original-Repository

Diese Vagrant-Labs sind eine alternative Umsetzung der Docker-Compose-Labs
aus dem Kursmaterial "Sichere Netzwerke" (FOM Hochschule). Die
Original-Labs, Vorlesungsunterlagen und Studierenden-Guides findest du im
Hauptteil dieses Repositories.
