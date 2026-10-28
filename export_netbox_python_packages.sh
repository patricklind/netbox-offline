#!/bin/bash
set -euo pipefail

# Export a complete offline NetBox 4.7.x wheelhouse.
# Run on an internet-connected host with the SAME OS/architecture and Python
# minor version as the offline NetBox server, against the target NetBox source.
#
# Usage:
#   sudo PYTHON=/usr/bin/python3.12 ./export_netbox_python_packages.sh
#
# Transfer netbox-python-packages-wheelhouse.tar.gz and its .sha256 to
# /opt/netbox on the offline host, verify sha256sum -c, then extract.

NETBOX_DIR="${NETBOX_DIR:-/opt/netbox}"
PYTHON="${PYTHON:-/usr/bin/python3.12}"
NETBOX_DIR="$(cd "$NETBOX_DIR" && pwd -P)"
WHEELHOUSE="${WHEELHOUSE:-${NETBOX_DIR}/wheelhouse}"
EXPORT_FILE="${EXPORT_FILE:-${NETBOX_DIR}/netbox-python-packages-wheelhouse.tar.gz}"
REQ_FILE="${NETBOX_DIR}/requirements.txt"
LOCAL_REQ_FILE="${NETBOX_DIR}/local_requirements.txt"

# The archive must always extract to ./wheelhouse for upgrade_offline.sh.
if [[ "$WHEELHOUSE" != "${NETBOX_DIR}/wheelhouse" ]]; then
  echo "ERROR: WHEELHOUSE must be ${NETBOX_DIR}/wheelhouse for this export format." >&2
  exit 1
fi
[[ -f "$REQ_FILE" && -f "${NETBOX_DIR}/netbox/release.yaml" ]] || {
  echo "ERROR: NetBox source or requirements.txt not found in $NETBOX_DIR" >&2
  exit 1
}
command -v "$PYTHON" >/dev/null 2>&1 || {
  echo "ERROR: Python not found: $PYTHON" >&2
  exit 1
}
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)' || {
  echo "ERROR: NetBox 4.7 requires Python 3.12 or later." >&2
  exit 1
}
echo "NetBox version: $(awk -F\" '/^version:/ {print $2}' "${NETBOX_DIR}/netbox/release.yaml")"
echo "Python: $("$PYTHON" -V)"
echo "Wheelhouse: $WHEELHOUSE"

# Build in a temporary directory: do not destroy an existing wheelhouse if
# downloading, wheel building or the offline self-test fails.
STAGING="$(mktemp -d "${NETBOX_DIR}/.wheelhouse-export.XXXXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT
BUILD_WHEELS="${STAGING}/wheelhouse"
TEST_VENV="${STAGING}/test-venv"
mkdir -p "$BUILD_WHEELS"

# Use a dedicated build environment to avoid modifying the export host Python.
"$PYTHON" -m venv "${STAGING}/build-venv"
BUILD_PY="${STAGING}/build-venv/bin/python"
"$BUILD_PY" -m pip install --upgrade pip setuptools wheel

echo "Building NetBox dependencies and bootstrap wheels..."
"$BUILD_PY" -m pip wheel --wheel-dir "$BUILD_WHEELS" pip setuptools wheel
"$BUILD_PY" -m pip wheel --wheel-dir "$BUILD_WHEELS" -r "$REQ_FILE"
if [[ -s "$LOCAL_REQ_FILE" ]]; then
  "$BUILD_PY" -m pip wheel --wheel-dir "$BUILD_WHEELS" -r "$LOCAL_REQ_FILE"
fi

# NetBox 4.7 upgrade.sh builds local documentation with 'zensical build'.
"$BUILD_PY" -m pip wheel --wheel-dir "$BUILD_WHEELS" zensical

echo "Validating installation with no network access..."
"$PYTHON" -m venv "$TEST_VENV"
TEST_PY="${TEST_VENV}/bin/python"
"$TEST_PY" -m pip install --no-index --find-links="$BUILD_WHEELS" --upgrade pip
"$TEST_PY" -m pip install --no-index --find-links="$BUILD_WHEELS" wheel
"$TEST_PY" -m pip install --no-index --find-links="$BUILD_WHEELS" -r "$REQ_FILE"
if [[ -s "$LOCAL_REQ_FILE" ]]; then
  "$TEST_PY" -m pip install --no-index --find-links="$BUILD_WHEELS" -r "$LOCAL_REQ_FILE"
fi
"$TEST_PY" -m pip install --no-index --find-links="$BUILD_WHEELS" zensical
"$TEST_PY" -m pip check
"${TEST_VENV}/bin/zensical" --version
"$TEST_PY" - <<'PY'
import django
import redis
import rq
print("Core Python dependency import test OK")
PY

{
  echo "NetBox Python offline wheelhouse"
  echo "Generated: $(date -Is)"
  echo "Python: $("$PYTHON" -V)"
  echo "NetBox version: $(awk -F\" '/^version:/ {print $2}' "${NETBOX_DIR}/netbox/release.yaml")"
  echo "OS: $(uname -srm)"
  echo "Note: Wheelhouse is for the same OS, architecture and Python ABI."
  echo
  find "$BUILD_WHEELS" -maxdepth 1 -type f -printf '%f\n' | sort
} > "${BUILD_WHEELS}/MANIFEST.txt"

# Publish only once a clean offline install has passed.
if [[ -e "$WHEELHOUSE" ]]; then
  mv "$WHEELHOUSE" "${STAGING}/previous-wheelhouse"
fi
mv "$BUILD_WHEELS" "$WHEELHOUSE"

# Produce the archive without replacing an existing export until tar succeeds.
TEMP_ARCHIVE="${EXPORT_FILE}.tmp.$$"
trap 'rm -f "$TEMP_ARCHIVE"; cleanup' EXIT
tar -czf "$TEMP_ARCHIVE" -C "$NETBOX_DIR" wheelhouse
mv -f "$TEMP_ARCHIVE" "$EXPORT_FILE"
sha256sum "$EXPORT_FILE" > "${EXPORT_FILE}.sha256"

echo "SUCCESS: $EXPORT_FILE"
echo "Checksum: ${EXPORT_FILE}.sha256"
echo "Offline steps:"
echo "  cd /opt/netbox"
echo "  sha256sum -c netbox-python-packages-wheelhouse.tar.gz.sha256"
echo "  tar -xzf netbox-python-packages-wheelhouse.tar.gz"
echo "  chown -R netbox:netbox /opt/netbox/wheelhouse"
echo "  PYTHON=$PYTHON ./upgrade_offline.sh"
