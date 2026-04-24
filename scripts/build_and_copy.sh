#!/bin/bash

# Define the source APK path
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

# Google Drive destination folder (rclone remote name: gdrive)
# Run `rclone config` once to set up the remote named "gdrive".
GDRIVE_REMOTE="gdrive"
GDRIVE_DEST="pico4/store"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
ask_yes_no() {
    # Usage: ask_yes_no "Question?" && do_something
    local PROMPT="$1"
    while true; do
        read -rp "${PROMPT} [y/n] " ANSWER
        case "$ANSWER" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

troubleshoot_rclone() {
    echo ""
    echo "---- rclone troubleshooter ----"

    # 1. Is rclone installed?
    if ! command -v rclone &>/dev/null; then
        echo "[FAIL] rclone is not installed."
        if ask_yes_no "Install rclone now via Homebrew?"; then
            brew install rclone || { echo "Homebrew install failed. Install manually: https://rclone.org/install/"; exit 1; }
            echo "[OK] rclone installed."
        else
            echo "Install rclone manually and re-run the script."
            exit 1
        fi
    else
        echo "[OK] rclone is installed: $(rclone --version | head -1)"
    fi

    # 2. Is the remote configured?
    if ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:"; then
        echo "[FAIL] rclone remote '${GDRIVE_REMOTE}' is not configured."
        if ask_yes_no "Run 'rclone config' now to set it up?"; then
            rclone config
            # Re-check after config
            if ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:"; then
                echo "[FAIL] Remote '${GDRIVE_REMOTE}' still not found after config. Make sure you named it '${GDRIVE_REMOTE}'."
                exit 1
            fi
            echo "[OK] Remote '${GDRIVE_REMOTE}' configured."
        else
            echo "Run 'rclone config' manually and create a remote named '${GDRIVE_REMOTE}'."
            exit 1
        fi
    else
        echo "[OK] rclone remote '${GDRIVE_REMOTE}' exists."
    fi

    # 3. Can we actually reach the remote? (quick ls with timeout)
    echo "Testing connectivity to ${GDRIVE_REMOTE}:..."
    if rclone lsd "${GDRIVE_REMOTE}:" --max-depth 1 &>/dev/null; then
        echo "[OK] Remote is reachable."
    else
        echo "[FAIL] Cannot reach remote '${GDRIVE_REMOTE}'. Possible causes:"
        echo "  - No internet connection"
        echo "  - Revoked OAuth token"
        echo "  - Wrong account authorised"
        if ask_yes_no "Re-authorize the remote now (rclone config reconnect)?"; then
            rclone config reconnect "${GDRIVE_REMOTE}:"
        else
            echo "Fix the remote manually with: rclone config reconnect ${GDRIVE_REMOTE}:"
            exit 1
        fi
    fi

    echo "---- troubleshooting complete ----"
    echo ""
}

# ---------------------------------------------------------------------------
# Dependency / config pre-flight
# ---------------------------------------------------------------------------
NEEDS_TROUBLESHOOT=0

if ! command -v rclone &>/dev/null; then
    echo "Error: 'rclone' not found."
    NEEDS_TROUBLESHOOT=1
elif ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:"; then
    echo "Error: rclone remote '${GDRIVE_REMOTE}' is not configured."
    NEEDS_TROUBLESHOOT=1
fi

if [[ $NEEDS_TROUBLESHOOT -eq 1 ]]; then
    if ask_yes_no "Run troubleshooter to fix the issue?"; then
        troubleshoot_rclone
    else
        echo "Aborting. Fix rclone setup and re-run."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Changelog generation
# ---------------------------------------------------------------------------
generate_changelog() {
    # Find the most recent release tag (format: release/YYYYMMDD_HHMM).
    local last_tag
    last_tag=$(git describe --tags --match "release/*" --abbrev=0 2>/dev/null || echo "")

    local log
    if [[ -n "$last_tag" ]]; then
        echo "Generating changelog since tag: ${last_tag}" >&2
        log=$(git log --no-merges --format="- %s" "${last_tag}..HEAD" 2>/dev/null)
    else
        echo "No previous release tag found — using last 20 commits." >&2
        log=$(git log --no-merges --format="- %s" -20 2>/dev/null)
    fi

    if [[ -z "$log" ]]; then
        echo "- No changes noted"
    else
        echo "$log"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "Building Flutter APK (Release)..."

# Generate changelog from git history (can be overridden via env var CHANGELOG).
if [[ -z "$CHANGELOG" ]]; then
    CHANGELOG=$(generate_changelog)
fi

echo ""
echo "==== Changelog for this release ===="
echo "$CHANGELOG"
echo "===================================="
echo ""

# Generate the build timestamp and embed it into lib/utils/build_info.dart
# so the app can compare itself against Drive APK filenames at runtime.
TIMESTAMP=$(date +"%Y%m%d_%H%M")
BUILD_INFO_FILE="lib/utils/build_info.dart"
echo "// AUTO-GENERATED by scripts/build_and_copy.sh — do not edit manually." > "$BUILD_INFO_FILE"
echo "// Format: YYYYMMDD_HHMM matching the uploaded APK filename convention." >> "$BUILD_INFO_FILE"
echo "const String kBuildTimestamp = '$TIMESTAMP';" >> "$BUILD_INFO_FILE"
echo "Embedded build timestamp $TIMESTAMP into $BUILD_INFO_FILE"

# ---------------------------------------------------------------------------
# upload_apk  path  dest  [retry_on_fail]
# Sets Drive file description to $CHANGELOG after a successful upload.
# ---------------------------------------------------------------------------
upload_apk() {
    local src="$1"
    local dest="$2"
    local filename="$3"

    # rclone >= 1.64 supports --metadata / --metadata-set for Drive description.
    # Newlines inside the value are passed safely because the variable is quoted.
    if rclone copyto "$src" "$dest" \
            --metadata \
            --metadata-set "description=${CHANGELOG}" \
            --progress; then
        echo "APK uploaded successfully to ${dest}"
        return 0
    fi
    return 1
}

if flutter build apk --release; then
    FILENAME="${TIMESTAMP}_store.apk"
    DEST_PATH="${GDRIVE_REMOTE}:${GDRIVE_DEST}/${FILENAME}"

    echo "Build successful! Uploading to ${DEST_PATH}..."

    if ! upload_apk "$APK_PATH" "$DEST_PATH" "$FILENAME"; then
        echo ""
        echo "Upload failed."
        if ask_yes_no "Run troubleshooter to diagnose the issue?"; then
            troubleshoot_rclone
            echo "Retrying upload..."
            if ! upload_apk "$APK_PATH" "$DEST_PATH" "$FILENAME"; then
                echo "Upload still failed. Check rclone logs with: rclone copyto \"$APK_PATH\" \"$DEST_PATH\" -vv"
                exit 1
            fi
        else
            exit 1
        fi
    fi

    # Tag the commit so the next build can generate an accurate changelog.
    RELEASE_TAG="release/${TIMESTAMP}"
    if git tag "$RELEASE_TAG" 2>/dev/null; then
        echo "Tagged release as ${RELEASE_TAG}"
    else
        echo "Note: tag ${RELEASE_TAG} already exists, skipping."
    fi
else
    echo "Build failed. Not uploading."
    exit 1
fi
