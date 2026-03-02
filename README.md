# netbox-offline

Offline-opgradering af NetBox på servere uden internetadgang.

Repoet indeholder:
- `upgrade_offline.sh`: opgraderingsscript der kan installere Python-afhængigheder fra en lokal `wheelhouse/`.

## Forudsætninger

- NetBox-kode ligger i `/opt/netbox` (eller tilsvarende mappe med `requirements*.txt` og `netbox/manage.py`).
- Python 3.10+ er installeret på offline-serveren.
- Du kan overføre filer fra en online server til offline-serveren.
- Hvis du bruger plugins, ligger de i `local_requirements.txt`.

Vigtigt:
- Byg wheels på en maskine med kompatibel OS/Python-arkitektur i forhold til målserveren.

## 1) Byg wheelhouse på en online server

Kør i NetBox-mappen:

```bash
cd /opt/netbox
mkdir -p wheelhouse

pip download --dest wheelhouse -r requirements.txt
pip download --dest wheelhouse -r local_requirements.txt
# Valgfrit (afhænger af dit setup):
pip download --dest wheelhouse -r base_requirements.txt
```

## 2) Overfør wheelhouse til offline NetBox-server

Eksempel med `scp`:

```bash
scp -r wheelhouse/ user@offline-server:/opt/netbox/wheelhouse/
```

## 3) Kør offline-opgraderingen

På offline-serveren:

```bash
cd /opt/netbox
chown -R netbox:netbox /opt/netbox
PYTHON=python3.11 ./upgrade_offline.sh
```

Hvis din wheelhouse ligger et andet sted:

```bash
WHEELHOUSE=/path/to/wheelhouse PYTHON=python3.11 ./upgrade_offline.sh
```

### Read-only mode

Hvis du kun vil installere dependencies og oprette venv (uden migrations):

```bash
PYTHON=python3.11 ./upgrade_offline.sh --readonly
```

## 4) Restart services

Efter en fuld opgradering:

```bash
sudo systemctl restart netbox netbox-rq
```

## Hvad scriptet gør

`upgrade_offline.sh`:
- Validerer at Python-versionen er 3.10 eller nyere.
- Sletter eksisterende `venv/` og opretter en ny.
- Installerer pakker fra `wheelhouse/` med `--no-index --find-links=...` hvis mappen findes.
- Kører NetBox vedligeholdelseskommandoer (migrate, collectstatic, reindex, clearsessions m.fl.), medmindre `--readonly` bruges.
- Sætter ejerskab til `netbox:netbox` på `/opt/netbox`.

## Fejlfinding

- `No wheelhouse directory found`:
  Scriptet falder tilbage til online `pip`. På en isoleret server vil det typisk fejle. Overfør `wheelhouse/` og kør igen.
- `Unsupported Python version`:
  Brug en nyere Python, fx `PYTHON=python3.11`.
- `No matching distribution found`:
  Wheels matcher ikke målmiljøet. Rebuild wheelhouse på kompatibel platform/Python-version.
