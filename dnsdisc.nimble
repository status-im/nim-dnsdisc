# Package

packageName   = "dnsdisc"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Nim discovery library supporting EIP-1459"
license       = "MIT or Apache License 2.0"

# Dependencies

requires "nim >= 1.2.0",
  "bearssl",
  "chronicles",
  "chronos",
  "eth",
  "secp256k1",
  "stew",
  "testutils",
  "unittest2",
  "nimcrypto"

# Helper functions

proc test(name: string, params = "-d:chronicles_log_level=DEBUG", lang = "c") =
  # XXX: When running `> NIM_PARAMS="-d:chronicles_log_level=INFO" make test2`
  # I expect compiler flag to be overridden, however it stays with whatever is
  # specified here.
  exec "nim " & lang & " -r " & params & " tests/" & name & ".nim"

task test, "Build & run all DNS discovery tests":
  test "all_tests"
