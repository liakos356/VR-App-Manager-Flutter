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
# Main
# ---------------------------------------------------------------------------
echo "Building Flutter APK (Release)..."
if flutter build apk --release; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M")
    FILENAME="${TIMESTAMP}_store.apk"
    DEST_PATH="${GDRIVE_REMOTE}:${GDRIVE_DEST}/${FILENAME}"

    echo "Build successful! Uploading to ${DEST_PATH}..."

    if rclone copyto "$APK_PATH" "$DEST_PATH" --progress; then
        echo "APK uploaded successfully to ${DEST_PATH}"
    else
        echo ""
        echo "Upload failed."
        if ask_yes_no "Run troubleshooter to diagnose the issue?"; then
            troubleshoot_rclone
            echo "Retrying upload..."
            if rclone copyto "$APK_PATH" "$DEST_PATH" --progress; then
                echo "APK uploaded successfully to ${DEST_PATH}"
            else
                echo "Upload still failed. Check rclone logs with: rclone copyto \"$APK_PATH\" \"$DEST_PATH\" -vv"
                exit 1
            fi
        else
            exit 1
        fi
    fi
else
    echo "Build failed. Not uploading."
    exit 1
fi
