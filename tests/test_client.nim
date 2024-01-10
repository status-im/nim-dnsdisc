{.used.}

import
  std/[sequtils, strutils, tables],
  chronos,
  stew/base64,
  testutils/unittests,
  ../dnsdisc/[tree, client]

procSuite "Test DNS Discovery: Client":

  # Suite setup
  # Create sample tree from EIP-1459
  var treeRecords {.threadvar.}: Table[string, string]

  treeRecords["nodes.example.org"] = "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"
  treeRecords["C7HRFPF3BLGF3YR4DY5KX3SMBE.nodes.example.org"] = "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
  treeRecords["JWXYDBPXYWG6FX3GMDIBFA6CJ4.nodes.example.org"] = "enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24"
  treeRecords["2XS2367YHAXJFGLZHVAWLQD4ZY.nodes.example.org"] = "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA"
  treeRecords["H4FHT4B454P6UXFD7JCYQ5PWDY.nodes.example.org"] = "enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI"
  treeRecords["MHTDO6TMUBRIA2XWG5LUDACK24.nodes.example.org"] = "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o"

  proc resolver(domain: string): Future[string] {.async.} =
    return treeRecords[domain]

  asyncTest "Resolve root":
    ## This tests resolving a root TXT entry at a given domain location,
    ## parsing the entry and verifying the signature.

    # Expected case

    let
      loc = parseLinkEntry("enrtree://AKPYQIUQIL7PSIACI32J7FGZW56E5FKHEFCCOFHILBIMW3M6LWXS2@nodes.example.org").tryGet()
      root = waitFor resolveRoot(resolver, loc)

    check:
      root.isOk()
      root[].eroot == "JWXYDBPXYWG6FX3GMDIBFA6CJ4"
      root[].lroot == "C7HRFPF3BLGF3YR4DY5KX3SMBE"
      root[].seqNo == 1
      root[].signature == Base64Url.decode("o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")

    # Invalid cases

    check:
      # Invalid signature
      (waitFor resolveRoot(resolver, parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@nodes.example.org").tryGet()))
      .error()
      .contains("Could not verify signature")

  asyncTest "Resolve subtree entry":
    ## This tests resolving a subtree TXT entry at a given subdomain,
    ## parsing the entry and verifying the subdomain hash.

    # Expected case

    let
      loc = parseLinkEntry("enrtree://AKPYQIUQIL7PSIACI32J7FGZW56E5FKHEFCCOFHILBIMW3M6LWXS2@nodes.example.org").tryGet()
      entry = waitFor resolveSubtreeEntry(resolver, loc, "2XS2367YHAXJFGLZHVAWLQD4ZY")

    check:
      entry.isOk()
      entry[].kind == Enr
      entry[].enrEntry == parseEnrEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet()

    # Invalid cases
    # Add invalid entry to example tree
    treeRecords["2XS2367YHAXJFGLZHVAWLQE4ZY.nodes.example.org"] = "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA"

    check:
      # Invalid hash
      (waitFor resolveSubtreeEntry(resolver, loc, "2XS2367YHAXJFGLZHVAWLQE4ZY"))
      .error()
      .contains("Could not verify subdomain hash")

    # Remove invalid entry for future tests
    treeRecords.del("2XS2367YHAXJFGLZHVAWLQE4ZY.nodes.example.org")

  asyncTest "Resolve all subtree entries":
    ## This tests resolving all subtree entries at a given root,
    ## parsing and verifying the entries

    # Expected case

    let
      loc = parseLinkEntry("enrtree://AKPYQIUQIL7PSIACI32J7FGZW56E5FKHEFCCOFHILBIMW3M6LWXS2@nodes.example.org").tryGet()
      rootEntry = (waitFor resolveRoot(resolver, loc)).tryGet()
      entries = waitFor resolveAllEntries(resolver, loc, rootEntry)

    # We expect 3 ENR entries and one link entry
    let
      enrs = entries.filterIt(it.kind == Enr).mapIt(it.enrEntry)
      links = entries.filterIt(it.kind == Link).mapIt(it.linkEntry)

    check:
      entries.len == 4
      enrs.len == 3
      enrs.contains(parseEnrEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet())
      enrs.contains(parseEnrEntry("enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI").tryGet())
      enrs.contains(parseEnrEntry("enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o").tryGet())
      links.len == 1
      links.contains(parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org").tryGet())

    # Invalid case
    proc invalidResolver(domain: string): Future[string] {.async.} =
      return ""

    check:
      # If no entries can be resolved without error, empty set will be returned
      (waitFor resolveAllEntries(invalidResolver, loc, rootEntry)).len == 0

  asyncTest "Sync tree":
    ## This tests creating a client at a specific domain location
    ## and syncing the entire tree at that location

    # Expected case

    let loc = parseLinkEntry("enrtree://AKPYQIUQIL7PSIACI32J7FGZW56E5FKHEFCCOFHILBIMW3M6LWXS2@nodes.example.org").tryGet()

    var
      client = Client(loc: loc, tree: Tree())
      tree = client.getTree(resolver)

    # Verify root
    check:
      tree.rootEntry.eroot == "JWXYDBPXYWG6FX3GMDIBFA6CJ4"
      tree.rootEntry.lroot == "C7HRFPF3BLGF3YR4DY5KX3SMBE"
      tree.rootEntry.seqNo == 1
      tree.rootEntry.signature == Base64Url.decode("o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")

    # Verify subtree entries
    let
      enrs = tree.getNodes()
      links = tree.getLinks()

    check:
      tree.entries.len == 4
      enrs.len == 3
      enrs.contains(parseEnrEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet())
      enrs.contains(parseEnrEntry("enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI").tryGet())
      enrs.contains(parseEnrEntry("enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o").tryGet())
      links.len == 1
      links.contains(parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org").tryGet())

    # Invalid cases
    proc invalidResolver(domain: string): Future[string] {.async.} =
      return ""

    proc validRootResolver(domain: string): Future[string] {.async.} =
      return "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"

    # Invalid case 1: Root entry fails to parse
    expect CatchableError:
      # Expect ResultError if not even root entry can be resolved
      discard client.getTree(invalidResolver)

    # Invalid case 2: Root parses, but no subtree entries
    let errTree = client.getTree(validRootResolver)

    check:
      # Root parses as expected, but no entries resolved
      errTree.rootEntry == parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA").tryGet()
      errTree.entries.len == 0

  asyncTest "Get node records":
    ## This tests getting node records from a client tree

    let loc = parseLinkEntry("enrtree://AKPYQIUQIL7PSIACI32J7FGZW56E5FKHEFCCOFHILBIMW3M6LWXS2@nodes.example.org").tryGet()

    var client = Client(loc: loc, tree: Tree())

    discard client.getTree(resolver)  # This syncs the tree

    # Verify enrs
    var
      expEnr1, expEnr2, expEnr3: Record

    check:
      expEnr1.fromURI("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA")
      expEnr2.fromURI("enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI")
      expEnr3.fromURI("enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o")

    let enrs = client.getNodeRecords()

    check:
      enrs.len == 3
      enrs.contains(expEnr1)
      enrs.contains(expEnr2)
      enrs.contains(expEnr3)
