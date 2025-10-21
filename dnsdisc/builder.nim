{.push raises: []}

import
  std/[sequtils, strformat, strutils, tables],
  stew/[base64, base32, byteutils],
  nimcrypto/[hash, keccak],
  results,
  ./tree

export tree

## A collection of utilities for constructing a Merkle Tree
## encoding a list of ENR and link entries.
## The tree consists of DNS TXT records.
##
## Discovery via DNS is based on https://eips.ethereum.org/EIPS/eip-1459
##
## This implementation is based on the Go implementation of EIP-1459
## at https://github.com/ethereum/go-ethereum/blob/master/p2p/dnsdisc


## How we determine MaxChildren: (Adapted from go-ethereum)
## https://github.com/ethereum/go-ethereum/blob/4d88974864c3ee84a24b1088064162b8dbab8ad5/p2p/dnsdisc/tree.go#L116-L146
##
## We want to keep the UDP size below 512 bytes. The UDP size is roughly:
## UDP length = 8 + UDP payload length ( 229 )
## UPD Payload length:
##  - dns.id 2
##  - dns.flags 2
##  - dns.count.queries 2
##  - dns.count.answers 2
##  - dns.count.auth_rr 2
##  - dns.count.add_rr 2
##  - queries (query-size + 6)
##  - answers :
##  	- dns.resp.name 2
##  	- dns.resp.type 2
##  	- dns.resp.class 2
##  	- dns.resp.ttl 4
##  	- dns.resp.len 2
##  	- dns.txt.length 1
##  	- dns.txt resp_data_size
## So the total size is roughly a fixed overhead of `39`, and the size of the
## query (domain name) and response.
## The query size is, for example, FVY6INQ6LZ33WLCHO3BPR3FH6Y.snap.mainnet.ethdisco.net (52)
## We also have some static data in the response, such as `enrtree-branch:`, and potentially
## splitting the response up with `" "`, leaving us with a size of roughly `400` that we need
## to stay below.
## The number `370` is used to have some margin for extra overhead (for example, the dns query
## may be larger - more subdomains).
const
  HashAbbrevSize = 1 + (16*13)/8                 # Size of an encoded hash (plus comma)
  MaxChildren* = 370 div toInt(HashAbbrevSize)   # 13 children. See comment above for explanation.

type
  BuilderResult*[T] = Result[T, string]

  Subtree* = object # A coherent section of a larger tree. Can contain branch and leaf nodes.
    subtreeRoot*: SubtreeEntry
    subtreeEntries*: seq[SubtreeEntry]

####################
# Helper functions #
####################

proc toTXTRecord*(rootEntry: RootEntry): BuilderResult[string] =
  ## Converts a root entry into its corresponding
  ## TXT record representation
  var txtRecord: string

  let sig = Base64Url.encode(rootEntry.signature)
  try:
    txtRecord = fmt"{RootPrefix} e={rootEntry.eroot} l={rootEntry.lroot} seq={rootEntry.seqNo} sig={sig}"
  except ValueError:
    return err("Failed to format root entry")

  return ok(txtRecord)

proc toTXTRecord*(subtreeEntry: SubtreeEntry): BuilderResult[string] =
  ## Converts a subtree entry into its corresponding
  ## TXT record representation
  var txtRecord: string

  case subtreeEntry.kind:
    of Enr:
      txtRecord = subtreeEntry.enrEntry.record.toURI()
    of Link:
      txtRecord = LinkPrefix & subtreeEntry.linkEntry.str
    of Branch:
      txtRecord = BranchPrefix & subtreeEntry.branchEntry.children.join(",")

  return ok(txtRecord)

proc subdomain*(subtreeEntry: SubtreeEntry): BuilderResult[string] =
  ## Computes the subdomain hash for a subtree entry
  ## The subdomain name of any entry is the base32
  ## encoding of the (abbreviated) keccak256 hash of
  ## its TXT record content.
  var txtRecord: string

  try:
    txtRecord = subtreeEntry.toTXTRecord().tryGet()
  except ValueError:
    return err("Failed to format subtree entry")

  let
    keccakHash = keccak256.digest(txtRecord.toBytes()).data[0..15]
    subdomain = Base32.encode(keccakHash)

  return ok(subdomain)

###############
# Builder API #
###############

proc buildTXT*(tree: Tree, domain: string): BuilderResult[Table[string, string]] =
  ## Builds the TXT records for a given tree at
  ## a given domain. Returns a map of (sub)domain
  ## to TXT record for the full tree.

  var treeRecords = initTable[string, string]()

  # Add root entry
  let rootRecordRes = tree.rootEntry.toTXTRecord()

  if rootRecordRes.isErr:
    return err("Failed to build: " & rootRecordRes.error)
  else:
    treeRecords[domain] = rootRecordRes.get()

  # Add subtree entries
  for subtreeEntry in tree.entries:
    let
      subdomainRes = subtreeEntry.subdomain()
      txtRecordRes = subtreeEntry.toTXTRecord()

    if subdomainRes.isErr:
      return err("Failed to build: " & subdomainRes.error)

    if txtRecordRes.isErr:
      return err("Failed to build: " & txtRecordRes.error)

    treeRecords[subdomainRes.get() & "." & domain] = txtRecordRes.get()

  return ok(treeRecords)

proc buildSubtree*(entries: seq[SubtreeEntry]): BuilderResult[Subtree] =
  ## Builds a subtree from a given list of entries.
  ## Returns the built subtree entries and the root of the subtree.
  var subtree: Subtree

  if entries.len() == 1:
    # Single entry is its own root
    subtree.subtreeRoot = entries[0]
    return ok(subtree)

  if entries.len() <= MaxChildren:
    # Entries will fit in single branch
    # Determine subdomain hashes
    var children: seq[string]

    for entry in entries:
      let subdomainRes = entry.subdomain()

      if subdomainRes.isErr:
        return err("Failed to build subtree: " & subdomainRes.error)

      children.add(subdomainRes.get())

    # Return branch as subtree
    subtree.subtreeRoot = SubtreeEntry(kind: Branch,
                                       branchEntry: BranchEntry(children: children))
    subtree.subtreeEntries = entries
    return ok(subtree)

  ## Several branches required. The algorithm is now:
  ## 1. Create a branch subtree for each slice of entries that fits within MaxChildren
  ## 2. Create a subtree consisting of the subtree root entries of all branches in (1)
  ## 3. Combine entries from (1) and (2) into a single subtree
  var
    subtrees: seq[Subtree]
    entriesToAdd = entries
  while entriesToAdd.len > 0:
    # Iterate until all entries are part of a subtree
    let sliceSize = if entriesToAdd.len < MaxChildren: entriesToAdd.len
                    else: MaxChildren

    let subtreeRes = buildSubtree(entriesToAdd[0..<sliceSize])

    if subtreeRes.isErr:
      return err(subtreeRes.error)

    subtrees.add(subtreeRes.get())

    entriesToAdd = entriesToAdd[sliceSize..<entriesToAdd.len] # Continue with remainder of entries

  # Collect entries and roots from all subtrees
  let
    combinedEntries = subtrees.mapIt(it.subtreeEntries).concat()
    combinedRoots = subtrees.mapIt(it.subtreeRoot)

  # Build a subtree from the roots of the existing subtrees. Recursion is fun!
  let rootsSubtreeRes = buildSubtree(combinedRoots)
  if rootsSubtreeRes.isErr:
    return err(rootsSubtreeRes.error)

  let rootsSubtree = rootsSubtreeRes.get()

  # Return combined subtree
  subtree.subtreeRoot = rootsSubtree.subtreeRoot
  subtree.subtreeEntries = concat(rootsSubtree.subtreeEntries, combinedEntries)
  return ok(subtree)

proc signTree*(tree: var Tree, privateKey: PrivateKey): BuilderResult[void] =
  ## Signs the tree with the provided private key
  var
    sig: Signature
    rootEntry = tree.rootEntry

  try:
    sig = sign(privateKey, hashableContent(rootEntry))
  except ValueError:
    return err("Failed to sign root entry")

  tree.rootEntry.signature = @(sig.toRaw())
  return ok()

proc buildTree*(seqNo: uint32,
                enrRecords: seq[Record],
                links: seq[LinkEntry]): BuilderResult[Tree] =
  ## Builds a tree from given lists of ENR and links.

  var tree: Tree

  # @TODO verify ENR here - should be signed

  # Convert ENR and links to subtree sequences
  var
    enrEntries: seq[SubtreeEntry]
    linkEntries: seq[SubtreeEntry]

  enrEntries = enrRecords.mapIt(SubtreeEntry(kind: Enr, enrEntry: EnrEntry(record: it)))
  linkEntries = links.mapIt(SubtreeEntry(kind: Link, linkEntry: it))

  # Build ENR and link subtrees

  let enrSubtreeRes = buildSubtree(enrEntries)

  if enrSubtreeRes.isErr:
    return err("Failed to build ENR subtree: " & enrSubtreeRes.error)

  let linkSubtreeRes = buildSubtree(linkEntries)

  if linkSubtreeRes.isErr:
    return err("Failed to build link subtree: " & linkSubtreeRes.error)

  # Create a root entry
  let
    erootRes = enrSubtreeRes.get().subtreeRoot.subdomain()
    lrootRes = linkSubtreeRes.get().subtreeRoot.subdomain()

  if erootRes.isErr or lrootRes.isErr:
    return err("Failed to determine subtree root subdomain")

  let rootEntry = RootEntry(eroot: erootRes.get(),
                            lroot: lrootRes.get(),
                            seqNo: seqNo)

  # Combine subtrees
  let entries = concat(@[enrSubtreeRes.get().subtreeRoot,
                         linkSubtreeRes.get().subtreeRoot],
                       enrSubtreeRes.get().subtreeEntries,
                       linkSubtreeRes.get().subtreeEntries)

  tree = Tree(rootEntry: rootEntry,
              entries: entries)

  return ok(tree)
