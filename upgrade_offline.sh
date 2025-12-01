#!/bin/bash

# Offline-aware NetBox upgrade script
# Baseret på commit dc4bab7477e05c491fc0b68477055712d4f96351

set -e

# --- Argumenter: readonly-mode ---------------------------------------------

if [[ "$1" == "--readonly" ]]; then
  READONLY_MODE=true
else
  READONLY_MODE=false
fi

# --- Skift til scriptets directory ----------------------------------------

cd "$(dirname "$0")"

#NETBOX_VERSION="$(grep ^version netbox/release.yaml | cut -d '\"' -f2)"
NETBOX_VERSION="$(awk -F\" '/^version:/ {print $2}' netbox/release.yaml)"
echo "You are installing (or upgrading to) NetBox version ${NETBOX_VERSION}"

VIRTUALENV="$(pwd -P)/venv"
PYTHON="${PYTHON:-python3}"

# --- Offline wheelhouse-konfiguration -------------------------------------

# Som standard forventes wheelhouse i ./wheelhouse
WHEELHOUSE_DEFAULT="$(pwd -P)/wheelhouse"
WHEELHOUSE="${WHEELHOUSE:-$WHEELHOUSE_DEFAULT}"

PIP_FLAGS=""

if [ -d "$WHEELHOUSE" ]; then
  echo "Using offline wheelhouse at: ${WHEELHOUSE}"
  PIP_FLAGS="--no-index --find-links=${WHEELHOUSE}"
else
  echo "WARNING: No wheelhouse directory found at: ${WHEELHOUSE}"
  echo "         Falling back to normal pip behavior (online PyPI)."
  echo "         Dette vil fejle/hænge på en server uden internet."
fi

# --- Tjek minimum Python-version (3.10+) ----------------------------------

COMMAND="${PYTHON} -c 'import sys; exit(1 if sys.version_info < (3, 10) else 0)'"
PYTHON_VERSION="$(${PYTHON} -V 2>&1 || true)"

if ! eval "$COMMAND"; then
  echo "--------------------------------------------------------------------"
  echo "ERROR: Unsupported Python version: ${PYTHON_VERSION}"
  echo "NetBox v4 kræver Python 3.10 eller nyere."
  echo ""
  echo "Brug evt.:"
  echo "  sudo PYTHON=/usr/bin/python3.10 $0"
  echo ""
  echo "Aktuel Python-version kan ses med:"
  echo "  ${PYTHON} -V"
  echo "--------------------------------------------------------------------"
  exit 1
fi

echo "Using ${PYTHON_VERSION}"

# --- Slet eksisterende venv og opret ny -----------------------------------

if [ -d "$VIRTUALENV" ]; then
  COMMAND="rm -rf \"${VIRTUALENV}\""
  echo "Removing old virtual environment..."
  eval "$COMMAND"
else
  WARN_MISSING_VENV=1
fi

COMMAND="${PYTHON} -m venv \"${VIRTUALENV}\""
echo "Creating a new virtual environment at ${VIRTUALENV}..."
if ! eval "$COMMAND"; then
  echo "--------------------------------------------------------------------"
  echo "ERROR: Failed to create the virtual environment."
  echo "Check at nødvendige systempakker er installeret, og at stien er"
  echo "skrivbar: ${VIRTUALENV}"
  echo "--------------------------------------------------------------------"
  exit 1
fi

# --- Aktivér venv ---------------------------------------------------------

# shellcheck source=/dev/null
source "${VIRTUALENV}/bin/activate"

# --- Opdater pip (offline hvis wheelhouse findes) -------------------------

COMMAND="pip install ${PIP_FLAGS} --upgrade pip"
echo "Updating pip (${COMMAND})..."
eval "$COMMAND"
pip -V

# --- Installer system-værktøjer (wheel) -----------------------------------

COMMAND="pip install ${PIP_FLAGS} wheel"
echo "Installing Python system packages (${COMMAND})..."
eval "$COMMAND"

# --- Installer core dependencies -----------------------------------------

COMMAND="pip install ${PIP_FLAGS} -r requirements.txt"
echo "Installing core dependencies (${COMMAND})..."
eval "$COMMAND"

# --- Installer lokale dependencies (hvis nogen) ---------------------------

if [ -s "local_requirements.txt" ]; then
  COMMAND="pip install ${PIP_FLAGS} -r local_requirements.txt"
  echo "Installing local dependencies (${COMMAND})..."
  eval "$COMMAND"
elif [ -f "local_requirements.txt" ]; then
  echo "Skipping local dependencies (local_requirements.txt is empty)"
else
  echo "Skipping local dependencies (local_requirements.txt not found)"
fi

# --- Database migrations ---------------------------------------------------

if [ "$READONLY_MODE" = true ]; then
  echo "Skipping database migrations (read-only mode)"
  exit 0
else
  COMMAND="python3 netbox/manage.py migrate"
  echo "Applying database migrations (${COMMAND})..."
  eval "$COMMAND"
fi

# --- Trace cable paths -----------------------------------------------------

COMMAND="python3 netbox/manage.py trace_paths --no-input"
echo "Checking for missing cable paths (${COMMAND})..."
eval "$COMMAND"

# --- Build dokumentation --------------------------------------------------

COMMAND="mkdocs build"
echo "Building documentation (${COMMAND})..."
eval "$COMMAND"

# --- Collect static files -------------------------------------------------

COMMAND="python3 netbox/manage.py collectstatic --no-input"
echo "Collecting static files (${COMMAND})..."
eval "$COMMAND"

# --- Fjern stale content types -------------------------------------------

COMMAND="python3 netbox/manage.py remove_stale_contenttypes --no-input"
echo "Removing stale content types (${COMMAND})..."
eval "$COMMAND"

# --- Rebuild søge-cache ---------------------------------------------------

COMMAND="python3 netbox/manage.py reindex --lazy"
echo "Rebuilding search cache (${COMMAND})..."
eval "$COMMAND"

# --- Fjern gamle sessions -------------------------------------------------

COMMAND="python3 netbox/manage.py clearsessions"
echo "Removing expired user sessions (${COMMAND})..."
eval "$COMMAND"

# --- Info om ny venv ------------------------------------------------------

if [ -v WARN_MISSING_VENV ]; then
  echo "--------------------------------------------------------------------"
  echo "WARNING: No existing virtual environment was detected."
  echo "A new one has been created. Opdatér evt. dine systemd service-filer:"
  echo ""
  echo "netbox.service ExecStart:"
  echo "  ${VIRTUALENV}/bin/gunicorn"
  echo ""
  echo "netbox-rq.service ExecStart:"
  echo "  ${VIRTUALENV}/bin/python"
  echo ""
  echo "Efter ændringer: "
  echo "  systemctl daemon-reload"
  echo "--------------------------------------------------------------------"
fi

chown -R netbox:netbox /opt/netbox
echo "Upgrade complete! Remember to restart the NetBox services:"
echo "  sudo systemctl restart netbox netbox-rq"