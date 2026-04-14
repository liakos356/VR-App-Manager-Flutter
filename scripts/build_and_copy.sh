#!/bin/bash

# Define the source APK path
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

# Define the destination directory
DEST_DIR="/Volumes/ssd_internal/downloads/pico4/store"

echo "Building Flutter APK (Release)..."
if flutter build apk --release; then
    echo "Build successful! Copying APK to $DEST_DIR..."
    
    # Create the destination directory if it doesn't exist
    mkdir -p "$DEST_DIR"
    
    # Copy the APK
    if cp "$APK_PATH" "$DEST_DIR/"; then
        echo "APK copied successfully!"
    else
        echo "Failed to copy the APK."
        exit 1
    fi
else
    echo "Build failed. Not copying."
    exit 1
fi
