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
| 03 | `labs/lab-03-tls-analyse` | TLS-Analyse | ✅ fertig | `lab03-net` |
| 04 | – | BGP-Verkehr-Analyse | – läuft ohne Docker/VMs, siehe Original-Repo | – |
| 05 | `labs/lab-05-dns-poisoning` | DNS Poisoning | ✅ fertig | `lab05-net` |

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

**Unterschiede zum Original (Docker-Lab):**

| Original (Docker) | Diese Version (Vagrant) |
|---|---|
| Container über `docker exec -it` | echte VMs über `vagrant ssh` |
| Interface heißt `eth1` | Interface heißt `enp0s9`/`enp0s8` (Ubuntu-Namensschema) |
| `setup.sh` setzte die Route nur beim `victim`-Container, **nicht** beim `server` – dadurch lief der MITM nicht zuverlässig (asymmetrisches Routing: die Antwort ging per normalem ARP direkt zurück zum Opfer, am Angreifer vorbei) | symmetrische Route auf **beiden** Seiten (`victim` **und** `server`) – das war der eigentliche Bugfix, den wir hier gefunden und dem Dozenten gemeldet haben; die offizielle Docker-Version wurde danach identisch korrigiert |
| Docker-Bridge-Netzwerk | VirtualBox `intnet` / Hyper-V-Switch (verhält sich eher wie ein gemeinsames LAN-Segment) |

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

**Unterschiede zum Original (Docker-Lab):**

| Original (Docker) | Diese Version (Vagrant) |
|---|---|
| Interface heißt `eth0` (Docker-Standard) | Interface heißt `enp0s8` (Ubuntu-Namensschema unter VirtualBox/Hyper-V) |
| `setup.sh` setzt `net.bridge.bridge-nf-call-iptables=0` u. ä., damit ARP-Spoofing über die Docker-Bridge überhaupt funktioniert (Linux-Bridge/Netfilter-Layer würde sonst dazwischenfunken) | komplett entfällt – VirtualBox `intnet`/Hyper-V-Switch hat keine Netfilter-Schicht dazwischen, ARP-Spoofing funktioniert ohne Sonderkonfiguration |
| Container über `docker exec -it` | echte VMs über `vagrant ssh` |

---

## Lab 03 – TLS-Analyse

**Netzwerk:** `10.30.0.0/24`

| VM | IP | Rolle |
|---|---|---|
| server | 10.30.0.10 | nginx mit TLS (443) + Klartext (80) |
| client | 10.30.0.20 | Verbindet sich zum Server |
| analyst | 10.30.0.30 | Schneidet den Netzwerkverkehr mit |

```bash
cd labs/lab-03-tls-analyse
vagrant up --provider=virtualbox
```

Das Server-Zertifikat wird automatisch generiert und landet bereits
fertig unter `~/server.crt` auf `client` (kein manueller Kopierschritt
nötig).

**Aufgabe 1 – TLS-Handshake beobachten (auf client):**

```bash
vagrant ssh client
```

```bash
echo | openssl s_client -connect 10.30.0.10:443 -CAfile ~/server.crt -state -msg 2>&1 | head -60
```

> Das `echo |` davor ist wichtig: ohne Eingabe wartet `openssl s_client`
> nach dem Handshake interaktiv auf stdin. Bricht man das stattdessen mit
> `head` einfach ab, meldet openssl "Broken pipe"-Fehler (harmlos, aber
> unschön) – mit `echo |` schickt man sauber ein EOF und openssl beendet
> sich selbst.

**Aufgabe 2 – Zertifikat analysieren (auf client):**

```bash
openssl x509 -in ~/server.crt -noout -subject -issuer -dates -fingerprint -sha256
```

Vergleiche den Fingerprint mit `~/expected-fingerprint.txt`.

**Aufgabe 3 – Netzwerkverkehr mitschneiden (zwei Terminals/Fenster nötig):**

`analyst` liegt hier – anders als `attacker` in Lab 01 oder `mallory` in
Lab 02 – nicht aktiv im Übertragungsweg, sondern schneidet nur passiv
mit. Damit die virtuelle NIC überhaupt fremden Verkehr sieht, ist im
Vagrantfile für `analyst` Promiscuous Mode aktiviert
(`--nicpromisc2 allow-all`) – ohne das bleibt der Mitschnitt leer.

Wichtig: tshark muss **laufen, bevor** der `curl`-Befehl auf `client`
abgeschickt wird – am einfachsten mit zwei parallel offenen
Terminal-Fenstern.

Fenster 1 (analyst) – laufen lassen, nicht mit `head`/Pipe abbrechen:
```bash
vagrant ssh analyst
sudo tshark -i enp0s8 -f "tcp port 443" -Y "tls" -V
```

Fenster 2 (client), sobald Fenster 1 "Capturing on 'enp0s8'" zeigt:
```bash
vagrant ssh client -c "curl -k https://10.30.0.10/api/secret"
```

Danach in Fenster 1 mit `Strg+C` stoppen.

Beobachtungsaufgabe: Der Inhalt der Antwort ist im TLS-Mitschnitt
**nicht** lesbar, nach dem Handshake ist nur noch "Application Data" zu
sehen. Jetzt zum Vergleich mit Klartext-HTTP (`-x` zeigt bei tshark den
Hex/ASCII-Dump, das Äquivalent zu tcpdump's `-A`):

Fenster 1 (analyst):
```bash
sudo tshark -i enp0s8 -f "tcp port 80" -x
```

Fenster 2 (client), sobald "Capturing on 'enp0s8'" steht:
```bash
vagrant ssh client -c "curl http://10.30.0.10/api/secret"
```

Danach in Fenster 1 mit `Strg+C` stoppen. Diesmal ist der komplette
HTTP-Request und die Antwort (inklusive `S3cr3tD4ta`) im Klartext lesbar
– sowohl im Hex-Dump als auch in der ASCII-Spalte daneben.

**Aufgabe 4 – TLS-Versionen und Cipher Suites (auf client):**

```bash
for VERSION in tls1_2 tls1_3; do
  echo "=== TLS $VERSION ==="
  echo | openssl s_client -connect 10.30.0.10:443 -CAfile ~/server.crt -$VERSION 2>&1 \
    | grep -E "(Protocol|Cipher|New|Reused)"
  echo ""
done
```

Beide Versionen handeln eine ECDHE-Cipher-Suite aus (`ECDHE-RSA-AES256-GCM-SHA384`
bei TLS 1.2, `TLS_AES_256_GCM_SHA384` bei TLS 1.3) – das steht für Perfect
Forward Secrecy: der Schlüsselaustausch erzeugt pro Verbindung ein neues,
temporäres Schlüsselpaar, sodass selbst ein späterer Diebstahl des
privaten Serverschlüssels vergangene Sitzungen nicht rückwirkend
entschlüsselbar macht.

**Aufgabe 5 (Bonus) – Sichtbare Metadaten trotz TLS (auf analyst):**

```bash
sudo tshark -i enp0s8 \
  -Y "tls.handshake.type == 1" \
  -T fields -e ip.src -e ip.dst \
  -e tls.handshake.extensions_server_name \
  -e tls.handshake.version
```

Parallel auf client mehrfach anfragen: `curl -sk https://10.30.0.10/api/secret`.
Auch bei TLS bleiben IP-Adressen und (falls SNI genutzt wird) der
angefragte Hostname sichtbar.

**Unterschiede zum Original (Docker-Lab):**

| Original (Docker) | Diese Version (Vagrant) |
|---|---|
| Zertifikat wird **auf dem Host** von `setup.sh` per `openssl` erzeugt und via `docker cp`/Volume-Mount in die Container gebracht | Zertifikat wird **im Server selbst** während des Provisionierens erzeugt; `client` lädt es sich per `curl` von Port 80 selbst herunter (ausgenutzt wird Vagrants sequenzielle Boot-Reihenfolge: `server` ist fertig, bevor `client` startet) – kein Host-seitiges Kopieren zwischen VMs nötig |
| Interface heißt `eth0` | Interface heißt `enp0s8` |
| `analyst` sitzt im selben Docker-Bridge-Netz und sieht fremden Verkehr automatisch mit | `analyst` braucht in VirtualBox explizit Promiscuous Mode (`--nicpromisc2 allow-all`), weil er nicht aktiv im Pfad liegt und VirtualBox-NICs standardmäßig nur an sie adressierte Frames erhalten |
| tcpdump/tshark-Befehle nutzen `eth0` und tcpdump-Flags (`-A`) | Befehle nutzen `enp0s8`; für tshark gilt `-x` statt tcpdump's `-A` |
| Container über `docker exec -it` | echte VMs über `vagrant ssh` |

---

## Lab 05 – DNS Poisoning

**Netzwerk:** `10.50.0.0/24`

| VM | IP | Rolle |
|---|---|---|
| victim | 10.50.0.10 | Hauptopfer |
| victim2 | 10.50.0.11 | zweites Opfer, zeigt den Cache-Effekt |
| resolver | 10.50.0.53 | rekursiver, cachender Resolver (unbound) |
| auth-dns | 10.50.0.54 | autoritativer Server für `bank.local` (nsd, DNSSEC-signiert) |
| web-real | 10.50.0.20 | echtes Banking-Portal |
| web-fake | 10.50.0.99 | Phishing-Klon |
| attacker | 10.50.0.66 | Angreifer (ettercap) |

```bash
cd labs/lab-05-dns-poisoning
vagrant up --provider=virtualbox
```

7 VMs – der erste `vagrant up` dauert entsprechend länger und braucht zusammen
ca. 3 GB RAM.

**Aufgabe 2 – Ausgangszustand (auf victim):**

```bash
vagrant ssh victim
```

```bash
getent ahostsv4 bank.local
curl -4 -s bank.local | grep -E "badge|Server:"
```

Sollte `10.50.0.20` und "ECHTES PORTAL" zeigen.

**Aufgabe 3 – Szenario A (Angriff direkt am Client):**

Auf `attacker`:

```bash
vagrant ssh attacker
sudo ettercap -T -q -i enp0s8 -M arp:remote /10.50.0.10// /10.50.0.53// -P dns_spoof
```

Laufen lassen, dann in einem anderen Fenster:

```bash
vagrant ssh victim -c "getent ahostsv4 bank.local"
vagrant ssh victim2 -c "getent ahostsv4 bank.local"
```

`victim` bekommt `10.50.0.99` (Phishing-Klon), `victim2` bleibt unbeeinflusst –
der Angriff sitzt gezielt zwischen `victim` und `resolver`, `victim2` ist nicht
betroffen. Angriff stoppen (`Strg+C`) und `victim` erneut fragen: die echte IP
kommt sofort zurück, nichts bleibt "vergiftet".

**Aufgabe 4 – Szenario B (Angriff am Resolver, wirkt auf alle Clients):**

Cache leeren, dann Angreifer auf das andere IP-Paar ansetzen:

```bash
vagrant ssh resolver -c "sudo unbound-control flush_zone bank.local."
```

```bash
vagrant ssh attacker
sudo ettercap -T -q -i enp0s8 -M arp:remote /10.50.0.53// /10.50.0.54// -P dns_spoof
```

Eine einzelne Anfrage von `victim` reicht, um den Cache zu vergiften:

```bash
vagrant ssh victim -c "getent ahostsv4 bank.local"
vagrant ssh resolver -c "sudo unbound-control dump_cache | grep bank.local"
```

Angriff stoppen, dann das bisher unbeteiligte `victim2` fragen:

```bash
vagrant ssh victim2 -c "getent ahostsv4 bank.local"
```

`victim2` bekommt trotzdem `10.50.0.99` – der Cache selbst ist vergiftet, nicht
nur eine einzelne Verbindung. Das wirkt so lange wie die TTL des gefälschten
Eintrags (bei ettercap standardmäßig 3600s), unabhängig davon, ob der
Angreifer noch aktiv ist.

**Aufgabe 5 – Szenario C (DNSSEC-Gegenmaßnahme):**

```bash
vagrant ssh resolver -c "sudo unbound-control flush_zone bank.local."
vagrant ssh resolver -c "sudo enable-dnssec.sh"
```

Szenario B wiederholen (Angreifer auf `/10.50.0.53// /10.50.0.54//`), dann:

```bash
vagrant ssh victim -c "dig @10.50.0.53 bank.local"
```

Ergebnis: `SERVFAIL` statt der gefälschten IP – die unsignierte, gefälschte
Antwort wird verworfen. Zum Vergleich ohne laufenden Angriff (Cache vorher
leeren): dieselbe Abfrage liefert ganz normal `10.50.0.20`.

> **Wichtige Beobachtung:** Wiederhole jetzt **Szenario A**
> (`/10.50.0.10// /10.50.0.53//`) bei weiterhin aktiver DNSSEC-Validierung:
>
> ```bash
> vagrant ssh victim -c "dig @10.50.0.53 bank.local +short"
> ```
>
> `victim` wird **trotzdem** getäuscht (`10.50.0.99`) – DNSSEC schützt nur den
> Weg zwischen validierendem Resolver und autoritativem Server, nicht die
> "letzte Meile" zwischen Client und Resolver. Der Stub-Resolver von `victim`
> validiert selbst nicht, sondern vertraut blind seinem Resolver.

Danach zurücksetzen:

```bash
vagrant ssh resolver -c "sudo disable-dnssec.sh"
```

**Bonus – DNS over TLS:**

```bash
vagrant ssh resolver -c "sudo enable-dot.sh"
```

**Unterschiede zum Original (Docker-Lab):**

| Original (Docker) | Diese Version (Vagrant) |
|---|---|
| DNS-Spoofing per `dsniff` (`arpspoof` + `dnsspoof`) | `dnsspoof` funktioniert auf dieser Ubuntu/VirtualBox-Kombination nicht zuverlässig (Traffic läuft nachweislich über den Angreifer, `dnsspoof` fängt ihn trotzdem nicht ab – vermutlich ein Kompatibilitätsproblem des alten, kaum noch gepflegten `dsniff`-Pakets). Stattdessen wie in Lab 02: **ettercap** mit `dns_spoof`-Plugin, das ARP-Poisoning und DNS-Fälschung in einem Tool erledigt |
| `attacker`/`attacker-fwd`: zwei Container, weil `ip_forward` unter Docker Desktop/WSL2 zur Laufzeit nicht änderbar ist (`/proc/sys` read-only) – Szenario-Wechsel = kompletter Container-Neustart | ein einziger `attacker`; ettercap übernimmt im `arp:remote`-Modus das Weiterleiten selbst – kein manuelles `ip_forward`-Umschalten nötig, Szenario-Wechsel = nur anderes IP-Ziel-Paar |
| Trust Anchor wird über ein Docker-Volume (`lab05-shared`) zwischen `auth-dns` und `resolver` geteilt | `auth-dns` stellt den Trust Anchor über einen simplen Python-`http.server` (Port 8090) bereit; `resolver` holt ihn sich per `curl` beim Aktivieren von DNSSEC – kein Host-seitiges Kopieren zwischen VMs, analog zum Zertifikats-Handoff in Lab 03 |
| IPs werden dynamisch per `docker inspect` ermittelt und in `.attack-cmds` geschrieben | IPs sind von vornherein statisch (kein DHCP in den Labs), direkt im Vagrantfile und in `/etc/lab-info` hinterlegt |
| `systemd-resolved` ist im Container kein Thema (Container haben kein eigenes systemd) | echte VMs haben `systemd-resolved` standardmäßig aktiv, das auf Port 53 (Loopback) bindet und mit `nsd`/`unbound`s `0.0.0.0`-Bind kollidiert (`Address already in use`) – muss auf `auth-dns`, `resolver`, `victim` und `victim2` vor dem Start der jeweiligen DNS-Dienste deaktiviert werden |
| Interface heißt `eth0` | Interface heißt `enp0s8` |
| Container über `docker exec -it` | echte VMs über `vagrant ssh` |

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

**Eigener DNS-Server (`nsd`/`unbound`) startet nicht, `systemctl status`
zeigt "Address already in use" auf Port 53:**
Ubuntu-VMs haben standardmäßig `systemd-resolved` aktiv, das auf
`127.0.0.x:53` lauscht. Ein `0.0.0.0`-Bind eines eigenen DNS-Dienstes deckt
das Loopback-Interface trotzdem mit ab und kollidiert deshalb. Vor dem
Start des eigenen Dienstes deaktivieren:

```bash
sudo systemctl disable --now systemd-resolved
sudo rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

(Erst *nach* eventuellen `apt-get install`-Schritten, die noch funktionierendes
DNS über den NAT-Adapter brauchen.)

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
