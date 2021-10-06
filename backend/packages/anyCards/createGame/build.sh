#!/bin/bash
# TEMP fixup the runtime and invoke /bin/defaultBuild explicitly.
# Once the runtime has the fixes needed, a build.sh will not be needed at all and we
# can just rely on the default build in the supported way.
set -e
cp sim-build/* /bin
/bin/defaultBuild
