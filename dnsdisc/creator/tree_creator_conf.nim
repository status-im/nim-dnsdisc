import
  confutils, confutils/defs, confutils/std/net,
  eth/p2p/discoveryv5/enr,
  eth/keys,
  results,
  ../tree

type
  TreeCreatorConf* = object
    # General config

    privateKey* {.
      desc: "Tree creator private key as 64 char hex string.",
      defaultValue: PrivateKey.random(newRng()[])
      name: "private-key" }: PrivateKey

    domain* {.
      desc: "Fully qualified domain name for the tree root entry",
      defaultValue: ""
      name: "domain" }: string

    enrRecords* {.
      desc: "Discoverable ENR entry in ENR text encoded format. Argument may be repeated."
      name: "enr-record" }: seq[Record]

    links* {.
      desc: "Discoverable link entry in link entry format. Argument may be repeated."
      name: "link" }: seq[LinkEntry]

    ## JSON-RPC config

    rpcAddress* {.
      desc: "Listening address of the JSON-RPC server.",
      defaultValue: ValidIpAddress.init("127.0.0.1")
      name: "rpc-address" }: ValidIpAddress

    rpcPort* {.
      desc: "Listening port of the JSON-RPC server.",
      defaultValue: 8545
      name: "rpc-port" }: uint16

##################
# Config parsing #
##################

proc parseCmdArg*(T: type PrivateKey, p: TaintedString): T =
  try:
    let pk = PrivateKey.fromHex(string(p)).tryGet()
    return pk
  except CatchableError:
    raise newException(ConfigurationError, "Invalid private key")

proc completeCmdArg*(T: type PrivateKey, val: TaintedString): seq[string] =
  return @[]

proc parseCmdArg*(T: type enr.Record, p: TaintedString): T =
  var enr: enr.Record

  if not fromURI(enr, p):
    raise newException(ConfigurationError, "Invalid ENR")

  return enr

proc completeCmdArg*(T: type enr.Record, val: TaintedString): seq[string] =
  return @[]

proc parseCmdArg*(T: type LinkEntry, p: TaintedString): T =
  try:
    let linkEntry = parseLinkEntry(string(p)).tryGet()
    return linkEntry
  except CatchableError:
    raise newException(ConfigurationError, "Invalid link entry")

proc completeCmdArg*(T: type LinkEntry, val: TaintedString): seq[string] =
  return @[]

proc parseCmdArg*(T: type ValidIpAddress, p: TaintedString): T =
  try:
    let ipAddr = ValidIpAddress.init(p)
    return ipAddr
  except CatchableError as e:
    raise newException(ConfigurationError, "Invalid IP address")

proc completeCmdArg*(T: type ValidIpAddress, val: TaintedString): seq[string] =
  return @[]
