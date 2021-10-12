#!/bin/bash
#
# Copyright (c) 2021 - present Joshua Auerbach
#
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

# This script installs the backend package.

# As part of a temporary workaround, the environment variable NIMBELLA_SWIFT_RUNTIME must be set to the
# location of a clone of https://github.com/joshuaauerbach/openwhisk-runtime-swift, branch
# remote-build-fixes.  Some fixes there are not yet present in production runtimes but can be patched in
# by the remote build script.  To avoid confusion and possible legal ambiguities, these fixes are not
# committed to this repo.

function fixup() {
		rm -fr "$1/sim-build"
		mkdir "$1/sim-build"
		cp "$NIMBELLA_SWIFT_RUNTIME/core/swift54Action/defaultBuild" "$1/sim-build"
		cp "$NIMBELLA_SWIFT_RUNTIME/core/swift54Action/swiftbuild.py" "$1/sim-build/compile"
		cp common/Package.swift $1
		cp common/Keys.swift common/Cleanup.swift $1/Sources
}

if [ -z "$NIMBELLA_SWIFT_RUNTIME" ]; then
	 echo "NIMBELLA_SWIFT_RUNTIME must be set in the environment"
   exit 1
fi

echo "Removing XCode metadata and derived  artifacts from the Action source"
find . -name .swiftpm -type d | xargs rm -fr
find . -name .build -type d | xargs rm -fr
find . -name Package.resolved -type f | xargs rm
find packages -name Package.swift -type f | xargs rm
find packages -name Keys.swift -type f | xargs rm
find packages -name Cleanup.swift -type f | xargs rm

echo "Fixing up the project with material that can't be committed to the repo or that is duplicated"
set -e
for i in createGame deleteGame poll newGameState withdraw; do
		fixup packages/anyCards/$i
done

echo "Starting project deployment (which will remotely build the actions)"
if ! nim project deploy . --env ~/.nimbella/anyCards.env --remote-build  --verbose; then
    echo "Build failed."
    exit 1
fi
