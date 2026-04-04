#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${REPO_ROOT}/.build"
PRODUCT_NAME="CLI"
COMMAND_NAME="qd"
RUN_TESTS=1
PACKAGE_VERSION="${PACKAGE_VERSION:-}"

usage() {
	cat <<'EOF'
Usage: Tools/build-package.sh [options]

Builds the QuickDev CLI in release mode and packages it for distribution.

Options:
  --skip-tests           Skip running swift test before packaging.
  --version <version>    Override the package version.
  --output-dir <path>    Override the output directory. Defaults to ./dist.
  -h, --help             Show this help.
EOF
}

extract_version() {
	local main_cli="${REPO_ROOT}/Sources/CLI/MainCLI.swift"
	local version

	version="$(sed -n 's/.*version: "\([^"]*\)".*/\1/p' "${main_cli}" | head -n 1)"

	if [[ -z "${version}" ]]; then
		echo "Failed to detect CLI version from ${main_cli}" >&2
		exit 1
	fi

	printf '%s\n' "${version}"
}

require_command() {
	local command_name="$1"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "Required command not found: ${command_name}" >&2
		exit 1
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-tests)
			RUN_TESTS=0
			shift
			;;
		--version)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --version" >&2
				exit 1
			fi
			PACKAGE_VERSION="$2"
			shift 2
			;;
		--output-dir)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --output-dir" >&2
				exit 1
			fi
			DIST_DIR="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

require_command swift
require_command tar
require_command shasum

PACKAGE_VERSION="${PACKAGE_VERSION:-$(extract_version)}"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
PACKAGE_BASENAME="quickdev-${PACKAGE_VERSION}-${PLATFORM}-${ARCH}"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickdev-package.XXXXXX")"
STAGING_DIR="${STAGING_ROOT}/${PACKAGE_BASENAME}"
ARCHIVE_PATH="${DIST_DIR}/${PACKAGE_BASENAME}.tar.gz"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

cleanup() {
	rm -rf "${STAGING_ROOT}"
}

trap cleanup EXIT

mkdir -p "${DIST_DIR}"

echo "==> Repository root: ${REPO_ROOT}"
echo "==> Package version: ${PACKAGE_VERSION}"

if [[ "${RUN_TESTS}" -eq 1 ]]; then
	echo "==> Running test suite"
	(
		cd "${REPO_ROOT}"
		swift test
	)
fi

echo "==> Building release binary"
(
	cd "${REPO_ROOT}"
	swift build -c release --product "${PRODUCT_NAME}"
)

BUILT_BINARY="${BUILD_DIR}/release/${PRODUCT_NAME}"

if [[ ! -x "${BUILT_BINARY}" ]]; then
	echo "Expected built binary was not found: ${BUILT_BINARY}" >&2
	exit 1
fi

echo "==> Staging package contents"
mkdir -p "${STAGING_DIR}/bin"
install -m 755 "${BUILT_BINARY}" "${STAGING_DIR}/bin/${COMMAND_NAME}"
install -m 644 "${REPO_ROOT}/LICENSE" "${STAGING_DIR}/LICENSE"

cat >"${STAGING_DIR}/README.txt" <<EOF
QuickDev CLI ${PACKAGE_VERSION}

Contents:
  bin/${COMMAND_NAME}    QuickDev executable
  install.sh            Installer for /usr/local/bin or ~/.local/bin

Quick start:
  1. Extract the archive.
  2. Run ./install.sh, or copy bin/${COMMAND_NAME} to a directory on your PATH.
  3. Verify installation with: ${COMMAND_NAME} --help
EOF

cat >"${STAGING_DIR}/install.sh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BINARY="${SCRIPT_DIR}/bin/qd"
DEFAULT_PREFIX="/usr/local/bin"
FALLBACK_PREFIX="${HOME}/.local/bin"

if [[ ! -x "${SOURCE_BINARY}" ]]; then
	echo "Binary not found: ${SOURCE_BINARY}" >&2
	exit 1
fi

if [[ -w "${DEFAULT_PREFIX}" ]] || [[ ! -e "${DEFAULT_PREFIX}" && -w "$(dirname "${DEFAULT_PREFIX}")" ]]; then
	TARGET_DIR="${DEFAULT_PREFIX}"
else
	TARGET_DIR="${FALLBACK_PREFIX}"
fi

mkdir -p "${TARGET_DIR}"
install -m 755 "${SOURCE_BINARY}" "${TARGET_DIR}/qd"

echo "Installed qd to ${TARGET_DIR}/qd"

case ":${PATH}:" in
	*":${TARGET_DIR}:"*) ;;
	*)
		echo "${TARGET_DIR} is not on PATH. Add this line to your shell profile:" >&2
		echo "  export PATH=\"${TARGET_DIR}:\$PATH\"" >&2
		;;
esac
EOF

chmod +x "${STAGING_DIR}/install.sh"

echo "==> Creating archive"
rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"
tar -C "${STAGING_ROOT}" -czf "${ARCHIVE_PATH}" "${PACKAGE_BASENAME}"
shasum -a 256 "${ARCHIVE_PATH}" >"${CHECKSUM_PATH}"

echo "==> Package created"
echo "Archive:  ${ARCHIVE_PATH}"
echo "SHA256:   ${CHECKSUM_PATH}"
