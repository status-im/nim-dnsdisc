{.push raises: [Defect]}

import
  ./tree

export
  tree

type
  Client* = object
    ## For now a client contains only a single tree in a single domain
    domain*: string
    tree: Tree

#######################
# Tree sync functions #
#######################

proc resolveNextEntry(subdomain: string): SubtreeEntry =
  ## Resolves subtree entry at given subdomain
  ## 
  ## @TODO implement
  
  return SubtreeEntry()

proc resolveAllEntries(rootEntry: RootEntry): seq[SubtreeEntry] =
  ## Resolves all subtree entries at given root
  ## Follows EIP-1459 client protocol
  ## 
  ## @TODO implement
  
  return newSeq[SubtreeEntry]()

proc resolveRoot(domain: string): RootEntry =
  ## Resolves root entry at given domain
  ## Also verifies the root signature and checks seq no
  ## Follows EIP-1459 client protocol
  ## 
  ## @TODO implement
  
  return RootEntry()

proc syncTree(c: Client): Tree =
  ## Synchronises the client tree according to EIP-1459
  c.tree.rootEntry = resolveRoot(domain)
  c.tree.entries = resolveAllEntries(c.tree.rootEntry)

  return c.tree

##############
# Client API #
##############

proc getTree*(c: Client): Tree =
  ## Main entry point into the client
  ## Returns a synchronised copy of the tree
  ## at the configured client domain
  ## 
  ## For now the client tree is (only) synchronised whenever accessed
  ## 
  ## @TODO periodically sync client tree and return only locally cached version
  return syncTree(c)
