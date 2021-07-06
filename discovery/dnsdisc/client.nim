{.push raises: [Defect]}

import
  std/strformat,
  chronicles,
  chronos,
  eth/keys,
  stew/[byteutils, results],
  ./tree

export
  tree

type
  Client* = object
    ## For now a client contains only a single tree in a single location
    loc*: LinkEntry
    tree*: var Tree
  
  ## A Resolver proc takes a DNS domain as argument and
  ## returns the TXT record at that domain
  Resolver* = proc(domain: string): Future[string]

  ResolveResult*[T] = Result[T, string]

const
  ResolverTimeout* = 20.seconds # Maximum time to wait for DNS resolution

#######################
# Tree sync functions #
#######################

proc resolveNextEntry(subdomain: string): ResolveResult[SubtreeEntry] =
  ## Resolves subtree entry at given subdomain
  ## 
  ## @TODO implement
  
  ok(SubtreeEntry())

proc resolveAllEntries(rootEntry: RootEntry): ResolveResult[seq[SubtreeEntry]] =
  ## Resolves all subtree entries at given root
  ## Follows EIP-1459 client protocol
  ## 
  ## @TODO implement
  
  ok(newSeq[SubtreeEntry]())

proc verifySignature(rootEntry: RootEntry, pubKey: PublicKey): bool {.raises: [Defect, ValueError].} =
  ## Verifies the signature on the root against the public key

  let
    sigHash = fmt"{RootPrefix} e={rootEntry.eroot} l={rootEntry.lroot} seq={rootEntry.seqNo}".toBytes()
    sig = SignatureNR.fromRaw(rootEntry.signature)

  if sig.isOk():
    trace "Verifying signature", sig=repr(sig[]), msg=repr(sigHash), key=repr(pubKey)
    return keys.verify(sig = sig[],
                       msg = sigHash,
                       key = pubKey)

proc parseAndVerifyRoot(txtRecord: string, loc: LinkEntry): EntryParseResult[RootEntry] {.raises: [Defect, ValueError].} =
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

proc resolveRoot*(resolver: Resolver, loc: LinkEntry): Future[ResolveResult[RootEntry]] {.async, raises: [Defect, ValueError].} =
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

proc syncTree*(c: Client, resolver: Resolver): Tree {.raises: [Defect, CatchableError].} =
  ## Synchronises the client tree according to EIP-1459
  ## 
  ## @TODO implement - this is a stub

  c.tree = Tree(rootEntry: (waitFor resolveRoot(resolver, c.loc)).tryGet(),
                entries: resolveAllEntries(c.tree.rootEntry).tryGet())

  return c.tree

##############
# Client API #
##############

proc getTree*(c: Client, resolver: Resolver): Tree {.raises: [Defect, CatchableError].} =
  ## Main entry point into the client
  ## Returns a synchronised copy of the tree
  ## at the configured client domain
  ## 
  ## For now the client tree is (only) synchronised whenever accessed
  ## 
  ## @TODO periodically sync client tree and return only locally cached version
  ## @TODO implement - this is a stub
  
  return syncTree(c, resolver)
