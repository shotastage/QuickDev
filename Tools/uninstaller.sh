#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR_OVERRIDE="${QUICKDEV_INSTALL_DIR:-}"
REMOVE_ALL_MATCHES="${QUICKDEV_REMOVE_ALL:-0}"

usage() {
	cat <<'EOF'
Usage: uninstaller.sh [options]

Uninstalls the QuickDev CLI (qd command).

By default this script removes qd from ~/.local/bin. If qd is found in another
location on PATH, that location is removed instead.

Options:
  --install-dir <path>  Directory containing qd. Defaults to auto-detect or ~/.local/bin.
  --all                 Remove all qd binaries found in PATH.
  -h, --help            Show this help.

Environment variables:
  QUICKDEV_INSTALL_DIR
  QUICKDEV_REMOVE_ALL=1

Examples:
  ./Tools/uninstaller.sh
  ./Tools/uninstaller.sh --install-dir ~/.local/bin
  ./Tools/uninstaller.sh --all
EOF
}

log() {
	printf '==> %s\n' "$*"
}

warn() {
	printf 'Warning: %s\n' "$*" >&2
}

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

resolve_home_dir() {
	local home_dir="${HOME:-}"

	if [[ -n "${home_dir}" ]]; then
		printf '%s\n' "${home_dir}"
		return
	fi

	if home_dir="$(cd ~ >/dev/null 2>&1 && pwd)"; then
		if [[ -n "${home_dir}" ]]; then
			printf '%s\n' "${home_dir}"
			return
		fi
	fi

	fail "HOME is not set. Set HOME or pass --install-dir."
}

remove_with_fallback() {
	local path="$1"

	if [[ ! -e "${path}" ]]; then
		warn "Not found: ${path}"
		return 1
	fi

	if rm -f "${path}" 2>/dev/null; then
		printf 'Removed %s\n' "${path}"
		return 0
	fi

	if command -v sudo >/dev/null 2>&1; then
		log "Removing ${path} with sudo"
		sudo rm -f "${path}"
		printf 'Removed %s\n' "${path}"
		return 0
	fi

	fail "Cannot remove ${path}. Try running with sufficient permissions."
}

default_install_dir() {
	if [[ -n "${INSTALL_DIR_OVERRIDE}" ]]; then
		printf '%s\n' "${INSTALL_DIR_OVERRIDE}"
		return
	fi

	printf '%s\n' "$(resolve_home_dir)/.local/bin"
}

find_qd_on_path() {
	command -v qd 2>/dev/null || true
}

collect_qd_matches_on_path() {
	local path_entry
	local candidate
	local old_ifs

	old_ifs="$IFS"
	IFS=':'
	for path_entry in ${PATH}; do
		candidate="${path_entry}/qd"
		if [[ -e "${candidate}" ]]; then
			printf '%s\n' "${candidate}"
		fi
	done
	IFS="$old_ifs"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--install-dir)
			[[ $# -ge 2 ]] || fail "Missing value for --install-dir"
			INSTALL_DIR_OVERRIDE="$2"
			shift 2
			;;
		--all)
			REMOVE_ALL_MATCHES=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			fail "Unknown argument: $1"
			;;
	esac
done

if [[ "${REMOVE_ALL_MATCHES}" == "1" ]]; then
	removed_any=0
	while IFS= read -r match; do
		if remove_with_fallback "${match}"; then
			removed_any=1
		fi
	done < <(collect_qd_matches_on_path)

	if [[ "${removed_any}" == "0" ]]; then
		warn "No qd binary found on PATH."
	fi
else
	target_dir="$(default_install_dir)"
	target_path="${target_dir}/qd"

	if [[ -n "${INSTALL_DIR_OVERRIDE}" ]]; then
		remove_with_fallback "${target_path}" || true
	else
		detected_path="$(find_qd_on_path)"
		if [[ -n "${detected_path}" ]]; then
			remove_with_fallback "${detected_path}" || true
		else
			remove_with_fallback "${target_path}" || true
		fi
	fi
fi

if command -v qd >/dev/null 2>&1; then
	warn "qd is still available on PATH. You may have additional installations."
	warn "Run with --all to remove every qd binary found in PATH."
else
	log "QuickDev uninstalled."
fi
