# netbox-offline

Offline upgrade of NetBox on servers without internet access.

The repository contains:
- `upgrade_offline.sh`: upgrade script that can install Python dependencies from a local `wheelhouse/`.

## Prerequisites

- The NetBox code is located in `/opt/netbox` (or an equivalent directory containing `requirements*.txt` and `netbox/manage.py`).
- Python 3.10+ is installed on the offline server.
- You are able to transfer files from an online server to the offline server.
- If you are using plugins, they are listed in `local_requirements.txt`.

**Important:**
- Build wheels on a machine with a compatible OS/Python architecture matching the target server.

## 1) Build wheelhouse on an online server

Run inside the NetBox directory:

```bash
cd /opt/netbox
mkdir -p wheelhouse

pip download --dest wheelhouse -r requirements.txt
pip download --dest wheelhouse -r local_requirements.txt
# Optional (depends on your setup):
pip download --dest wheelhouse -r base_requirements.txt
```

## 2) Transfer wheelhouse to the offline NetBox server

Example using `scp`:

```bash
scp -r wheelhouse/ user@offline-server:/opt/netbox/wheelhouse/
```

## 3) Run the offline upgrade

On the offline server:

```bash
cd /opt/netbox
chown -R netbox:netbox /opt/netbox
PYTHON=python3.11 ./upgrade_offline.sh
```

If your wheelhouse is located elsewhere:

```bash
WHEELHOUSE=/path/to/wheelhouse PYTHON=python3.11 ./upgrade_offline.sh
```

### Read-only mode

If you only want to install dependencies and create the virtual environment (without running migrations):

```bash
PYTHON=python3.11 ./upgrade_offline.sh --readonly
```

## 4) Restart services

After a full upgrade:

```bash
sudo systemctl restart netbox netbox-rq
```

## What the script does

`upgrade_offline.sh`:

- Validates that the Python version is 3.10 or newer.
- Deletes the existing `venv/` and creates a new one.
- Installs packages from `wheelhouse/` using `--no-index --find-links=...` if the directory exists.
- Runs NetBox maintenance commands (`migrate`, `collectstatic`, `reindex`, `clearsessions`, etc.), unless `--readonly` is used.
- Sets ownership to `netbox:netbox` on `/opt/netbox`.

## Troubleshooting

- `No wheelhouse directory found`  
  The script falls back to online `pip`. On an isolated server this will typically fail. Transfer `wheelhouse/` and run again.

- `Unsupported Python version`  
  Use a newer Python version, for example: `PYTHON=python3.11`.

- `No matching distribution found`  
  The wheels do not match the target environment. Rebuild the wheelhouse on a compatible platform/Python version.
