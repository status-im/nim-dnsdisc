when withDir(thisDir(), system.fileExists("nimbus-build-system.paths")):
  if getEnv("NIMBUS_BUILD_SYSTEM") == "yes":
    include "nimbus-build-system.paths"
