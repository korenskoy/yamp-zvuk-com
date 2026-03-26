#!/bin/bash

SWIFTLINT=".build/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"

if [ ! -f "$SWIFTLINT" ]; then
    echo "SwiftLint binary not found, running 'swift package resolve'..."
    swift package resolve
fi

"$SWIFTLINT" lint --fix "$@"
