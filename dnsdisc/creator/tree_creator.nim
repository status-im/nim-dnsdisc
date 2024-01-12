{.push raises: [Defect]}

## A utility module to create a Merkle tree encoding
## a list of ENR and link entries. This is a standalone
## module that can be run as a CLI application. It exposes
## a JSON-RPC API.

import
  std/[options, tables],
  chronos,
  chronicles,
  stew/base32,
  stew/results,
  ../builder

logScope:
  topics = "tree.creator"

type
  TreeCreator* = object
    privateKey: PrivateKey
    domain: Option[string]
    seqNo: uint32
    enrRecords: seq[Record]
    links: seq[LinkEntry]
    tree: Option[Tree]
    isUpdated: bool

  CreatorResult*[T] = Result[T, string]

##############
# Public API #
##############

proc setDomain*(tc: var TreeCreator, domain: string) =
  tc.domain = some(domain)

proc getDomain*(tc: TreeCreator): Option[string] =
  tc.domain

proc addEnrEntries*(tc: var TreeCreator, enrRecords: seq[string]): bool =
  debug "adding enr entries"

  var isSuccess = true

  for enrRecord in enrRecords:
    # Attempt to create ENR from strings
    var enr: Record
    if enr.fromURI(enrRecord):
      tc.enrRecords.add(enr)
      tc.isUpdated = true
    else:
      debug "Failed to parse ENR entry", enrRecord=enrRecord
      isSuccess = false

  return isSuccess

proc getEnrEntries*(tc: TreeCreator): seq[Record] =
  tc.enrRecords

proc addLinkEntries*(tc: var TreeCreator, links: seq[string]): bool =
  debug "adding link entries"

  var isSuccess = true

  for link in links:
    # Attempt to parse link entries
    let parsedLinkRes = parseLinkEntry(link)

    if parsedLinkRes.isOk:
      tc.links.add(parsedLinkRes.get())
      tc.isUpdated = true
    else:
      debug "Failed to parse link entry", link=link
      isSuccess = false

  return isSuccess

proc getLinkEntries*(tc: TreeCreator): seq[LinkEntry] =
  tc.links

proc buildTree*(tc: var TreeCreator): CreatorResult[Tree] =
  ## Attempts to build the tree, if it has not been built yet
  ## or if it has since been updated

  debug "attempting to build tree"

  if tc.tree.isSome() and not tc.isUpdated:
    # We've already built a tree and there has been no update since.
    debug "no update. returning tree."
    return ok(tc.tree.get())

  var tree: Tree

  if tc.enrRecords.len == 0 and tc.links.len == 0:
    # No entries to encode
    return err("no enr or link entries configured")

  # Build tree from existing entries. Increase seq no as per EIP-1459.
  tc.seqNo = tc.seqNo + 1
  let treeRes = buildTree(tc.seqNo, tc.enrRecords, tc.links)

  if treeRes.isErr():
    return err(treeRes.error)

  # Sign tree
  tree = treeRes[]

  let signRes = tree.signTree(tc.privateKey)

  if signRes.isErr():
    return err(signRes.error)

  # Cache signed tree on creator and reset isUpdated state
  tc.tree = some(tree)
  tc.isUpdated = false

  return ok(tree)

proc getTXTs*(tc: var TreeCreator): CreatorResult[Table[string, string]] =
  debug "getting TXT records"

  if tc.domain.isNone():
    return err("Failed to create: no domain configured")

  # Attempt to build tree, if necessary
  let buildRes = tc.buildTree()

  if buildRes.isErr():
    return err("Failed to create: " & buildRes.error)

  # Extract TXT records
  let txtRes = tc.tree.get().buildTXT(tc.domain.get())

  if txtRes.isErr():
    return err("Failed to create: " & txtRes.error)

  return ok(txtRes[])

proc getPublicKey*(tc: TreeCreator): string =
  ## Returns the compressed 32 byte public key
  ## in base32 encoding. This forms the "username"
  ## part of the tree location URL as per
  ## https://eips.ethereum.org/EIPS/eip-1459

  Base32.encode(tc.privateKey.toPublicKey().toRawCompressed())

proc getURL*(tc: TreeCreator): CreatorResult[string] =
  ## Returns the tree URL in the format
  ## 'enrtree://<public_key>@<domain>' as per
  ## https://eips.ethereum.org/EIPS/eip-1459

  if tc.domain.isNone():
    return err("Failed to create: no domain configured")

  return ok(LinkPrefix & tc.getPublicKey & "@" & tc.domain.get())

##########################
# Creator initialization #
##########################

proc init*(T: type TreeCreator,
           privateKey: PrivateKey,
           domain = none(string),
           enrRecords: seq[Record] = @[],
           links: seq[LinkEntry] = @[]): T =

  let treeCreator = TreeCreator(
    privateKey: privateKey,
    domain: domain,
    seqNo: 0,               # No sequence no yet, as tree has not been built
    enrRecords: enrRecords,
    links: links,
    isUpdated: true         # Indicates that tree requires a build
  )

  return treeCreator

{.pop.} # @TODO confutils.nim(775, 17) Error: can raise an unlisted exception: ref IOError
when isMainModule:
  import
    confutils,
    stew/shims/net as stewNet,
    ./tree_creator_conf,
    ./tree_creator_rpc

  logScope:
    topics = "tree.creator.setup"

  let
    conf = TreeCreatorConf.load()

  # 1/2 Initialise TreeCreator
  debug "1/2 initialising"

  let domain = if conf.domain == "": none(string)
               else: some(conf.domain)

  var treeCreator = TreeCreator.init(conf.privateKey,
                                     domain,
                                     conf.enrRecords,
                                     conf.links)

  # 2/2 Install JSON-RPC API handlers
  debug "2/2 starting RPC API"

  treeCreator.startRpc(conf.rpcAddress, Port(conf.rpcPort))

  debug "setup complete"

  runForever()
