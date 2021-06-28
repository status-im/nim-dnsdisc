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
