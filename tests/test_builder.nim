{.used.}

import
  std/[sequtils, tables],
  testutils/unittests,
  chronos,
  ./test_utils,
  ../discovery/dnsdisc/builder

procSuite "Test DNS Discovery: Merkle Tree builder":
  # Test tree entries:
  let
    rootStr = "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"
    enrStr = "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o"
    linkStr = "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
    branchStr = "enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24"
    rootEntry = parseRootEntry(rootStr).get()
    enrEntry = parseSubtreeEntry(enrStr).get()
    linkEntry = parseSubtreeEntry(linkStr).get()
    branchEntry = parseSubtreeEntry(branchStr).get()
    enrSubdomain = "MHTDO6TMUBRIA2XWG5LUDACK24"
    linkSubdomain = "C7HRFPF3BLGF3YR4DY5KX3SMBE"
    branchSubdomain = "JWXYDBPXYWG6FX3GMDIBFA6CJ4"
  
  asyncTest "Create TXT records":
    check:
      # Can convert (back) to TXT record
      rootEntry.toTXTRecord().get() == rootStr
      enrEntry.toTXTRecord().get() == enrStr
      linkEntry.toTXTRecord().get() == linkStr
      branchEntry.toTXTRecord().get() == branchStr
  
  asyncTest "Determine subdomain":
    check:
      # Successfully compute subdomain hash for each entry
      enrEntry.subdomain().get() == enrSubdomain
      linkEntry.subdomain().get() == linkSubdomain
      branchEntry.subdomain().get() == branchSubdomain

  asyncTest "Build TXT records":
    check:
      # Successfully build TXT records from example tree
      exampleTree.buildTXT("nodes.example.org").get() == exampleRecords
  
  asyncTest "Build subtree entries":
    let subtree = buildSubtree(@[parseSubtreeEntry(exampleRecords["2XS2367YHAXJFGLZHVAWLQD4ZY.nodes.example.org"]).get(),
                                 parseSubtreeEntry(exampleRecords["H4FHT4B454P6UXFD7JCYQ5PWDY.nodes.example.org"]).get(),
                                 parseSubtreeEntry(exampleRecords["MHTDO6TMUBRIA2XWG5LUDACK24.nodes.example.org"]).get()])
    check:
      # Successfully build ENR subtree
      subtree.isOk()
      subtree[].subtreeRoot.kind == Branch
      subtree[].subtreeRoot.branchEntry.children == @["2XS2367YHAXJFGLZHVAWLQD4ZY", "H4FHT4B454P6UXFD7JCYQ5PWDY", "MHTDO6TMUBRIA2XWG5LUDACK24"]
      subtree[].subtreeEntries.len == 3

  asyncTest "Build complete tree":
    var
      enr1: Record
      enr2: Record
      enr3: Record
      link = "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
      seqNo = 1.uint32
    
    check:
      enr1.fromBase64("-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA")
      enr2.fromBase64("-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI")
      enr3.fromBase64("-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o")

    let tree = buildTree(seqNo, @[enr1, enr2, enr3], @[link])

    check:
      # Successfully build example tree
      tree.isOk()
      # Root entry
      tree[].rootEntry.seqNo == 1
      tree[].rootEntry.eroot == rootEntry.eroot
      tree[].rootEntry.lroot == rootEntry.lroot
      # Subtree entries
      tree[].entries.len == 5
      tree[].entries.filterIt(it.kind == Branch).len == 1
      tree[].getNodes().len == 3
      tree[].getLinks().len == 1
