#!/usr/bin/env bash
# Sync Path of Destiny to a Windows SMB share for desktop Godot testing.
# Target: smb://darrell@192.168.1.50/godot/path-of-destiny
#
# Setup (once):
#   cp sync_windows.conf.example sync_windows.conf    # optional overrides
#   cp sync_windows.credentials.example sync_windows.credentials
#   chmod 600 sync_windows.credentials
#   # edit sync_windows.credentials and set SMB_PASSWORD
#
# Usage:
#   ./sync_windows.sh
#   SMB_PASSWORD='...' ./sync_windows.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${SOURCE:-${SCRIPT_DIR}}"

SMB_HOST="${SMB_HOST:-192.168.1.50}"
SMB_USER="${SMB_USER:-darrell}"
SMB_SHARE="${SMB_SHARE:-godot}"
SMB_REMOTE_DIR="${SMB_REMOTE_DIR:-path-of-destiny}"
SMB_MOUNT_POINT="${SMB_MOUNT_POINT:-}"

CONFIG="${SCRIPT_DIR}/sync_windows.conf"
CREDS="${SCRIPT_DIR}/sync_windows.credentials"

if [[ -f "${CONFIG}" ]]; then
	# shellcheck source=/dev/null
	source "${CONFIG}"
fi

if [[ -f "${CREDS}" ]]; then
	# shellcheck source=/dev/null
	source "${CREDS}"
fi

if [[ -z "${SMB_PASSWORD:-}" ]]; then
	echo "==> Windows SMB sync skipped (no SMB_PASSWORD or sync_windows.credentials)" >&2
	exit 0
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "rsync is required for sync_windows.sh" >&2
	exit 1
fi

MOUNT_POINT="${SMB_MOUNT_POINT:-}"
CREATED_MOUNT=0
if [[ -z "${MOUNT_POINT}" ]]; then
	MOUNT_POINT="$(mktemp -d /tmp/path-of-destiny-smb-XXXXXX)"
	CREATED_MOUNT=1
fi

cleanup() {
	if [[ "${CREATED_MOUNT}" -eq 1 ]] && mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
		if [[ "${EUID}" -eq 0 ]]; then
			umount "${MOUNT_POINT}" || true
		else
			sudo umount "${MOUNT_POINT}" || true
		fi
	fi
	if [[ "${CREATED_MOUNT}" -eq 1 ]]; then
		rmdir "${MOUNT_POINT}" 2>/dev/null || true
	fi
}
trap cleanup EXIT

REMOTE_ROOT="//${SMB_HOST}/${SMB_SHARE}"
MOUNT_OPTS="username=${SMB_USER},password=${SMB_PASSWORD},vers=3.0,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755"

mkdir -p "${MOUNT_POINT}"
if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
	echo "==> Using already-mounted ${MOUNT_POINT}"
else
	echo "==> Mounting ${REMOTE_ROOT}"
	if [[ "${EUID}" -eq 0 ]]; then
		mount -t cifs "${REMOTE_ROOT}" "${MOUNT_POINT}" -o "${MOUNT_OPTS}"
	else
		sudo mount -t cifs "${REMOTE_ROOT}" "${MOUNT_POINT}" -o "${MOUNT_OPTS}"
	fi
fi

DEST="${MOUNT_POINT}/${SMB_REMOTE_DIR}"
mkdir -p "${DEST}"

echo "==> Syncing ${SOURCE} -> ${REMOTE_ROOT}/${SMB_REMOTE_DIR}"
rsync -a --delete \
	--exclude='.git/' \
	--exclude='.cursor/' \
	--exclude='.godot/' \
	--exclude='sync_windows.credentials' \
	--exclude='sync_windows.conf' \
	"${SOURCE}/" "${DEST}/"

echo "==> Windows sync complete: smb://${SMB_USER}@${SMB_HOST}/${SMB_SHARE}/${SMB_REMOTE_DIR}"
echo "    Open in Godot on Windows: \\\\${SMB_HOST}\\${SMB_SHARE}\\${SMB_REMOTE_DIR}"
