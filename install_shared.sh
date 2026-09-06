#!/usr/bin/env bash
# Install Path of Destiny to a system-wide location any user can run.
# Usage: sudo ./install_shared.sh
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/path-of-destiny}"
LAUNCHER="${LAUNCHER:-/usr/local/bin/path-of-destiny}"
GODOT="${GODOT:-/godot/Godot_v4.7.2-stable_linux.x86_64}"
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
	echo "Run with sudo so files can be copied to ${INSTALL_DIR}" >&2
	exit 1
fi

echo "==> Installing from ${SOURCE} to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
rsync -a --delete \
	--exclude='.git' \
	"${SOURCE}/" "${INSTALL_DIR}/"

echo "==> Setting permissions (readable/executable by all users)"
chmod -R a+rX "${INSTALL_DIR}"
find "${INSTALL_DIR}" -type f -name '*.sh' -exec chmod 755 {} \;

echo "==> Installing launcher ${LAUNCHER}"
cat > "${LAUNCHER}" <<EOF
#!/usr/bin/env bash
exec "${GODOT}" --path "${INSTALL_DIR}" "\$@"
EOF
chmod 755 "${LAUNCHER}"

if [[ "${SYNC_WINDOWS:-1}" != "0" && -x "${SOURCE}/sync_windows.sh" ]]; then
	echo ""
	echo "==> Syncing to Windows desktop (SMB)"
	bash "${SOURCE}/sync_windows.sh" || echo "WARNING: Windows SMB sync failed (continuing)" >&2
fi

echo ""
echo "Done. Any user can now run:"
echo "  path-of-destiny"
echo "  path-of-destiny --path ${INSTALL_DIR}   # same thing"
echo ""
echo "Or directly:"
echo "  ${GODOT} --path ${INSTALL_DIR}"
