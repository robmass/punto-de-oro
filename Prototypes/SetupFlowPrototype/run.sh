#!/bin/sh
# PROTOTYPE — generate the throwaway Xcode project and open it.
# In Xcode: pick your Personal Team under Signing, choose your Apple Watch as destination, press Run.
set -e
cd "$(dirname "$0")"
xcodegen generate --quiet
open SetupFlowPrototype.xcodeproj
