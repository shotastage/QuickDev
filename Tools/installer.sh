#!/usr/bin/env bash

set -euo pipefail

REPO_SLUG="${QUICKDEV_REPO:-shotastage/QuickDev}"
VERSION_REQUEST="${QUICKDEV_VERSION:-latest}"
DEFAULT_BRANCH="${QUICKDEV_BRANCH:-main}"
INSTALL_DIR_OVERRIDE="${QUICKDEV_INSTALL_DIR:-}"
KEEP_TEMP_DIR="${QUICKDEV_KEEP_TEMP:-0}"
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
SCRIPT_DIR="${PWD}"
LOCAL_BINARY=""
WORK_DIR=""

if [[ -n "${SCRIPT_SOURCE}" && -f "${SCRIPT_SOURCE}" ]]; then
	SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
	LOCAL_BINARY="${SCRIPT_DIR}/bin/qd"
fi

usage() {
	cat <<'EOF'
Usage: installer.sh [options]

Installs the QuickDev CLI as the qd command.

By default this installer downloads QuickDev source from GitHub, builds it on
your Apple Silicon Mac, and installs qd to ~/.local/bin. If the script is run
from an extracted QuickDev archive containing bin/qd, it installs that bundled
binary instead.

Options:
  --version <tag>       Git tag to install. Defaults to latest source from main.
  --repo <owner/repo>   GitHub repository slug. Defaults to shotastage/QuickDev.
  --branch <branch>     Branch used when --version is not specified.
  --install-dir <path>  Target directory for qd. Defaults to ~/.local/bin.
  --keep-temp           Preserve temporary files for debugging.
  -h, --help            Show this help.

Environment variables:
  QUICKDEV_VERSION
  QUICKDEV_REPO
  QUICKDEV_BRANCH
  QUICKDEV_INSTALL_DIR
  QUICKDEV_KEEP_TEMP=1

Examples:
  curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash
  curl -fsSL https://raw.githubusercontent.com/shotastage/QuickDev/main/Tools/installer.sh | bash -s -- --version v0.0.1
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

cleanup() {
	if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" && "${KEEP_TEMP_DIR}" != "1" ]]; then
		rm -rf "${WORK_DIR}"
	fi
}

trap cleanup EXIT

require_command() {
	local command_name="$1"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		fail "Required command not found: ${command_name}"
	fi
}

path_contains() {
	case ":${PATH}:" in
		*":$1:"*)
			return 0
			;;
		*)
			return 1
			;;
	esac
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

default_install_dir() {
	if [[ -n "${INSTALL_DIR_OVERRIDE}" ]]; then
		printf '%s\n' "${INSTALL_DIR_OVERRIDE}"
		return
	fi

	printf '%s\n' "$(resolve_home_dir)/.local/bin"
}

install_binary() {
	local source_binary="$1"
	local target_dir="$2"
	local target_path="${target_dir}/qd"

	if [[ ! -x "${source_binary}" ]]; then
		fail "Binary not found or not executable: ${source_binary}"
	fi

	if [[ -d "${target_dir}" ]]; then
		:
	elif mkdir -p "${target_dir}" 2>/dev/null; then
		:
	elif command -v sudo >/dev/null 2>&1; then
		log "Creating ${target_dir} with sudo"
		sudo mkdir -p "${target_dir}"
	else
		fail "Cannot create installation directory: ${target_dir}"
	fi

	if install -m 755 "${source_binary}" "${target_path}" 2>/dev/null; then
		:
	elif command -v sudo >/dev/null 2>&1; then
		log "Installing qd to ${target_path} with sudo"
		sudo install -m 755 "${source_binary}" "${target_path}"
	else
		fail "Cannot write to installation directory: ${target_dir}"
	fi

	printf 'Installed qd to %s\n' "${target_path}"

	if ! path_contains "${target_dir}"; then
		warn "${target_dir} is not on PATH. Add this line to your shell profile:"
		warn "  export PATH=\"${target_dir}:\$PATH\""
	fi

	log "Verify with: qd --help"
}

assert_supported_platform() {
	if [[ "$(uname -s)" != "Darwin" ]]; then
		fail "QuickDev currently supports Apple Silicon macOS only."
	fi

	if [[ "$(uname -m)" != "arm64" ]]; then
		fail "QuickDev currently supports Apple Silicon Macs only. Detected architecture: $(uname -m)"
	fi
}

download_to_file() {
	local url="$1"
	local destination="$2"

	log "Downloading ${url}"
	curl -fL "${url}" -o "${destination}"
}

extract_archive() {
	local archive_path="$1"
	local destination_dir="$2"

	tar -xzf "${archive_path}" -C "${destination_dir}"
}

find_first_directory() {
	local search_root="$1"

	find "${search_root}" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

normalize_version() {
	local version_value="$1"

	version_value="${version_value#v}"
	printf '%s\n' "${version_value}"
}

validate_source_version() {
	local source_dir="$1"
	local version_file
	local source_version
	local requested_version

	version_file="${source_dir}/VERSION"
	if [[ ! -f "${version_file}" ]]; then
		fail "VERSION file not found in downloaded source."
	fi

	source_version="$(tr -d '[:space:]' < "${version_file}")"
	if [[ -z "${source_version}" ]]; then
		fail "VERSION file is empty in downloaded source."
	fi

	if [[ "${VERSION_REQUEST}" == "latest" ]]; then
		log "Resolved source version: ${source_version}"
		return
	fi

	requested_version="$(normalize_version "${VERSION_REQUEST}")"
	if [[ "$(normalize_version "${source_version}")" != "${requested_version}" ]]; then
		fail "Requested version ${VERSION_REQUEST} does not match source VERSION ${source_version}."
	fi

	log "Resolved source version: ${source_version}"
}

download_source_archive() {
	local destination="$1"
	local source_url
	local ref_candidates=()
	local candidate_ref

	if [[ "${VERSION_REQUEST}" == "latest" ]]; then
		ref_candidates+=("heads/${DEFAULT_BRANCH}")
	else
		ref_candidates+=("tags/${VERSION_REQUEST}")
		if [[ "${VERSION_REQUEST}" == v* ]]; then
			ref_candidates+=("tags/${VERSION_REQUEST#v}")
		else
			ref_candidates+=("tags/v${VERSION_REQUEST}")
		fi
	fi

	for candidate_ref in "${ref_candidates[@]}"; do
		source_url="https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/${candidate_ref}"
		if curl -fsIL "${source_url}" >/dev/null 2>&1; then
			download_to_file "${source_url}" "${destination}"
			return 0
		fi
	done

	return 1
}

install_from_source() {
	local target_dir="$1"
	local source_archive
	local source_root
	local source_dir
	local built_binary

	require_command swift

	if [[ -z "${WORK_DIR}" ]]; then
		WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quickdev-install.XXXXXX")"
	fi

	source_archive="${WORK_DIR}/quickdev-source.tar.gz"
	source_root="${WORK_DIR}/source"
	mkdir -p "${source_root}"

	if ! download_source_archive "${source_archive}"; then
		fail "Could not find a source archive for ${REPO_SLUG}."
	fi

	extract_archive "${source_archive}" "${source_root}"
	source_dir="$(find_first_directory "${source_root}")"
	if [[ -z "${source_dir}" ]]; then
		fail "Source archive extraction failed."
	fi

	validate_source_version "${source_dir}"

	log "Building QuickDev from source"
	(
		cd "${source_dir}"
		swift build -c release --product CLI
	)

	built_binary="${source_dir}/.build/release/CLI"
	if [[ ! -x "${built_binary}" ]]; then
		fail "Expected build output not found: ${built_binary}"
	fi

	install_binary "${built_binary}" "${target_dir}"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--version)
			[[ $# -ge 2 ]] || fail "Missing value for --version"
			VERSION_REQUEST="$2"
			shift 2
			;;
		--repo)
			[[ $# -ge 2 ]] || fail "Missing value for --repo"
			REPO_SLUG="$2"
			shift 2
			;;
		--branch)
			[[ $# -ge 2 ]] || fail "Missing value for --branch"
			DEFAULT_BRANCH="$2"
			shift 2
			;;
		--install-dir)
			[[ $# -ge 2 ]] || fail "Missing value for --install-dir"
			INSTALL_DIR_OVERRIDE="$2"
			shift 2
			;;
		--keep-temp)
			KEEP_TEMP_DIR=1
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

assert_supported_platform
require_command curl
require_command tar

TARGET_DIR="$(default_install_dir)"

if [[ -n "${LOCAL_BINARY}" && -x "${LOCAL_BINARY}" ]]; then
	log "Installing bundled archive binary"
	install_binary "${LOCAL_BINARY}" "${TARGET_DIR}"
	exit 0
fi

install_from_source "${TARGET_DIR}"
