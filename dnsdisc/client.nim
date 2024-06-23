{.push raises: []}

import
  std/[sequtils, sets, strformat],
  chronicles,
  chronos,
  eth/keys,
  nimcrypto/[hash, keccak],
  stew/[base32, byteutils, results],
  ./tree

export
  tree

## Implementation of DNS-based discovery client protocol, as specified
## in https://eips.ethereum.org/EIPS/eip-1459
##
## This implementation is loosely based on the Go implementation of EIP-1459
## at https://github.com/ethereum/go-ethereum/blob/master/p2p/dnsdisc

logScope:
  topics = "dnsdisc.client"

type
  Client* = object
    ## For now a client contains only a single tree in a single location
    loc*: LinkEntry
    tree*: Tree

  ## A Resolver proc takes a DNS domain as argument and
  ## returns the TXT record at that domain
  Resolver* = proc(domain: string): Future[string] {.async.}

  ResolveResult*[T] = Result[T, string]

const
  ResolverTimeout* = 20.seconds # Maximum time to wait for DNS resolution

#######################
# Tree sync functions #
#######################

proc parseAndVerifySubtreeEntry(txtRecord: string, hashStr: string): EntryParseResult[SubtreeEntry] {.raises: [ValueError, Base32Error].} =
  ## Parses subtree TXT entry and verifies that it matches the hash

  let res = parseSubtreeEntry(txtRecord)

  if res.isErr():
    # Return error result
    trace "Failed to parse subtree entry", record=txtRecord
    return res

  let
    subtreeEntry = res[]
    checkHash = Base32.decode(hashStr)
    entryHash = keccak256.digest(txtRecord.toBytes()).data

  trace "Verifying parsed subtree entry", subtreeEntry=subtreeEntry

  if entryHash[0..checkHash.len - 1] != checkHash:
    # Check that entryHash starts with checkHash
    trace "Failed to verify subdomain hash", subtreeEntry=subtreeEntry, hashStr=hashStr
    return err("Could not verify subdomain hash")

  ok(subtreeEntry)

proc resolveSubtreeEntry*(resolver: Resolver, loc: LinkEntry, subdomain: string): Future[ResolveResult[SubtreeEntry]] {.async, gcsafe, raises: [ValueError, Base32Error].} =
  ## Resolves subtree entry at given subdomain
  ## Follows EIP-1459 client protocol

  let lookupFut = resolver(subdomain & "." & loc.domain)

  if not await withTimeout(lookupFut, ResolverTimeout):
    error "Failed to resolve DNS record", domain=subdomain
    return err("Resolution failure: timeout")

  let txtRecord = lookupFut.read()

  trace "Resolving entry record", domain=subdomain, record=txtRecord

  let res = parseAndVerifySubtreeEntry(txtRecord, subdomain)

  if res.isErr():
    error "Failed to parse and verify subtree entry", domain=loc.domain, record=txtRecord
    return err("Resolution failure: " & res.error())

  return ok(res[])

proc resolveAllEntries*(resolver: Resolver, loc: LinkEntry, rootEntry: RootEntry): Future[seq[SubtreeEntry]] {.async.} =
  ## Resolves all subtree entries at given root
  ## Follows EIP-1459 client protocol

  var subtreeEntries: seq[SubtreeEntry]

  var
    # Initialise a hash set with the root hashes of ENR and link subtrees
    hashes = toHashSet([rootEntry.eroot, rootEntry.lroot])
    i = 1

  while hashes.len > 0 and i <= 100:
    # Recursively resolve leaf entries and add to return list.
    # @TODO: Define a better depth limit. 100 was chosen arbitrarily.
    inc(i)

    let
      # Resolve and remove random entry from subdomain hashes
      nextHash = hashes.pop()
      nextEntry = await resolveSubtreeEntry(resolver, loc, nextHash)

    if nextEntry.isErr():
      # @TODO metrics to track missing/failed entries
      trace "Could not resolve next entry. Continuing.", subdomain=nextHash
      continue

    case nextEntry[].kind:
      of Enr:
        # Add to return list
        subtreeEntries.add(nextEntry[])
      of Link:
        # Add to return list
        subtreeEntries.add(nextEntry[])
      of Branch:
        # Add branch children to hashes, and continue resolving
        hashes.incl(nextEntry[].branchEntry.children.toHashSet())

  return subtreeEntries

proc verifySignature(rootEntry: RootEntry, pubKey: PublicKey): bool =
  ## Verifies the signature on the root against the public key
  let sig = SignatureNR.fromRaw(rootEntry.signature)

  var sigHash: seq[byte]
  try:
    sigHash = hashableContent(rootEntry)
  except ValueError:
    return false

  if sig.isOk():
    trace "Verifying signature", sig=repr(sig[]), msg=repr(sigHash), key=repr(pubKey)
    return verify(sig = sig[],
                  msg = sigHash,
                  key = pubKey)

proc parseAndVerifyRoot(txtRecord: string, loc: LinkEntry): EntryParseResult[RootEntry] =
  ## Parses root TXT record and verifies signature

  let res = parseRootEntry(txtRecord)

  if res.isErr():
    # Return error result
    trace "Failed to parse root record", record=txtRecord
    return res

  let rootEntry = res[]

  trace "Verifying parsed root entry", rootEntry=rootEntry

  if not verifySignature(rootEntry, loc.pubKey):
    trace "Failed to verify signature", rootEntry=rootEntry, pubKey=loc.pubKey
    return err("Could not verify signature")

  ok(rootEntry)

proc resolveRoot*(resolver: Resolver, loc: LinkEntry): Future[ResolveResult[RootEntry]] {.async.} =
  ## Resolves root entry at given location (LinkEntry)
  ## Also verifies the root signature and checks seq no
  ## Follows EIP-1459 client protocol

  let lookupFut = resolver(loc.domain)

  if not await withTimeout(lookupFut, ResolverTimeout):
    error "Failed to resolve DNS record", domain=loc.domain
    return err("Resolution failure: timeout")

  let txtRecord = lookupFut.read()

  info "Updating DNS discovery root", domain=loc.domain, record=txtRecord

  let res = parseAndVerifyRoot(txtRecord, loc)

  if res.isErr():
    error "Failed to parse and verify root entry", domain=loc.domain, record=txtRecord
    return err("Resolution failure: " & res.error())

  return ok(res[])

proc syncTree(resolver: Resolver, rootLocation: LinkEntry): Future[Result[Tree, cstring]] {.async.} =
  ## Synchronises the client tree according to EIP-1459

  let rootEntry = await resolveRoot(resolver, rootLocation)

  if rootEntry.isErr:
    return err("Failed to resolve root entry")

  let
    subtreeEntries = await resolveAllEntries(resolver, rootLocation, rootEntry.get())
    tree = Tree(rootEntry: rootEntry.get(),
                entries: subtreeEntries)

  return ok(tree)

##############
# Client API #
##############

proc init*(T: type Client,
           locationUrl: string): Result[T, cstring] =
  ## Initialise client from a DNS node list URL
  ## with format 'enrtree://<key>@<fqdn>'

  let locLink = parseLinkEntry(locationUrl)

  if locLink.isErr:
     return err("Failed to create client")

  return ok(Client(loc: locLink.get()))

proc getNodeRecords*(c: Client): seq[Record] =
  ## Returns a list of node records in the client tree

  try:
    return c.tree.getNodes().mapIt(it.record)
  except ValueError:
    return @[]

proc getTree*(c: var Client, resolver: Resolver): Tree {.raises: [CatchableError].} =
  ## Main entry point into the client
  ## Returns a synchronised copy of the tree
  ## at the configured client domain
  ##
  ## For now the client tree is (only) synchronised whenever accessed.
  ## Note that this is a blocking operation to maintain memory safety
  ## on var Client
  ##
  ## @TODO periodically sync client tree and return only locally cached version

  c.tree = (waitFor syncTree(resolver, c.loc)).tryGet()

  return c.tree
