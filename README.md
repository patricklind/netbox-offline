# NetBox offline upgrade

Offline NetBox upgrade tools, intended for NetBox 4.7.x with Python 3.12+.

- `upgrade_offline.sh`: uses the local `/opt/netbox/wheelhouse` for dependency installation.
- `export_netbox_python_packages.sh`: builds, tests and packages wheels on an internet-connected build machine.

## Requirements

On the build machine, check out the **same target NetBox release** as on the offline server. Use the same Linux architecture, Python minor version and compatible OS as the target server. The exporter requires access to the Python package index.

Local plugin Python dependencies must be listed in `/opt/netbox/local_requirements.txt` on the build machine. It is not enough to copy only the Python wheels if a plugin requires native OS libraries.

## Export on the internet-connected build machine

```bash
cd /opt/netbox
sudo PYTHON=/usr/bin/python3.12 ./export_netbox_python_packages.sh
```

The exporter installs dependencies into a disposable virtual environment and performs an **offline** installation test before publishing `wheelhouse/`. It includes `zensical`, which is required for the NetBox 4.7 documentation build.

Outputs:
- `/opt/netbox/netbox-python-packages-wheelhouse.tar.gz`
- `/opt/netbox/netbox-python-packages-wheelhouse.tar.gz.sha256`

## Import on the offline server

Transfer the tarball and checksum to `/opt/netbox`. Then:

```bash
cd /opt/netbox
sha256sum -c netbox-python-packages-wheelhouse.tar.gz.sha256
sudo tar -xzf netbox-python-packages-wheelhouse.tar.gz
sudo chown -R netbox:netbox /opt/netbox/wheelhouse
```

**Before any upgrade**, back up PostgreSQL and the NetBox configuration, verify plugin compatibility, and arrange a maintenance window. Database migrations are not undone by restoring the Python venv.

```bash
cd /opt/netbox
bash -n upgrade_offline.sh
sudo PYTHON=/usr/bin/python3.12 ./upgrade_offline.sh
sudo systemctl restart netbox netbox-rq
```

The `--readonly` flag retains the original behavior: it skips migrations and later management commands, but still recreates the virtual environment. It is **not** a dry run.

The default wheelhouse path in the upgrade script remains relative to its location (`$(pwd -P)/wheelhouse`). The archive extracts into that same directory.

## Troubleshooting

- `Offline wheelhouse not found`: verify that `/opt/netbox/wheelhouse` contains extracted `.whl` files and unset any incorrect `WHEELHOUSE` environment variable.
- `No matching distribution found`: build the wheelhouse using the target release's requirements and a compatible OS, architecture and Python version.
- Documentation build fails: verify the `zensical` command is installed in the new venv.
