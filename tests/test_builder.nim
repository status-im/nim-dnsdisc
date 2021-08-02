{.used.}

import
  chronos,
  std/[sequtils, strformat, tables],
  testutils/unittests,
  ../discovery/dnsdisc/builder,
  ./test_utils

procSuite "Test DNS Discovery: Merkle Tree builder":
  # Test tree entries:
  
  asyncTest "Create TXT records":
    check:
      # Can convert (back) to TXT record
      exampleRoot.toTXTRecord().get() == RootTxt
      exampleEnr1.toTXTRecord().get() == Enr1Txt
      exampleLink.toTXTRecord().get() == LinkTxt
      exampleBranch.toTXTRecord().get() == BranchTxt
  
  asyncTest "Determine subdomain":
    check:
      # Successfully compute subdomain hash for each entry
      exampleEnr1.subdomain().get() == Enr1Subdomain
      exampleLink.subdomain().get() == LinkSubdomain
      exampleBranch.subdomain().get() == BranchSubdomain

  asyncTest "Build TXT records":
    check:
      # Successfully build all TXT records from example tree
      exampleTree.buildTXT("nodes.example.org").get() == exampleRecords
  
  asyncTest "Build subtree entries":
    # Test subtree from single leaf entry
    let subtreeLeaf = buildSubtree(@[parseSubtreeEntry(Enr1Txt).get()])
    check:
      subtreeLeaf.isOk()
      subtreeLeaf[].subtreeRoot.kind == Enr
      subtreeLeaf[].subtreeEntries.len == 0

    # Test subtree with single branch and leafs
    let subtreeSingle = buildSubtree(@[parseSubtreeEntry(Enr1Txt).get(),
                                       parseSubtreeEntry(Enr2Txt).get(),
                                       parseSubtreeEntry(Enr3Txt).get()])
    check:
      # Successfully build ENR subtree
      subtreeSingle.isOk()
      subtreeSingle[].subtreeRoot.kind == Branch
      subtreeSingle[].subtreeRoot.branchEntry.children == @[Enr1Subdomain, Enr2Subdomain, Enr3Subdomain]
      subtreeSingle[].subtreeEntries.len == 3
    
    # Test subtree with multiple branches-of-branches
    var entries: seq[SubtreeEntry]
    for i in 1..(MaxChildren*MaxChildren):
      # We need at least MaxChildren branch entries holding MaxChildren leaf nodes
      entries.add(parseSubtreeEntry(Enr1Txt).get())
    
    let
      subtreeMultiple = buildSubtree(entries)
      expectedLeafCount = MaxChildren*MaxChildren
      expectedBranchCount = MaxChildren # Excluding subtree root branch
    check:
      subtreeMultiple.isOk()
      subtreeMultiple[].subtreeRoot.kind == Branch
      subtreeMultiple[].subtreeEntries.len == expectedLeafCount + expectedBranchCount
      subtreeMultiple[].subtreeEntries.filterIt(it.kind == Enr).len == expectedLeafCount
      subtreeMultiple[].subtreeEntries.filterIt(it.kind == Branch).len == expectedBranchCount

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
      tree[].rootEntry.eroot == exampleRoot.eroot
      tree[].rootEntry.lroot == exampleRoot.lroot
      # Subtree entries
      tree[].entries.len == 5
      tree[].entries.filterIt(it.kind == Branch).len == 1
      tree[].getNodes().len == 3
      tree[].getLinks().len == 1
  
  asyncTest "Sign tree":
    let
      secKeyHex = "58d23b55bc9cdce1f18c2500f40ff4ab7245df9a89505e9b1fa4851f623d241d"
      expectedSig = "8BGq3_ZasQUPvDyU7cqBpsHVjn4CP5GsFf7Xf9M1bJARCXII3SrD7e_I8Q6qw9oLItHapevgFlfPfwhqPXFRrAA"
      expectedTXT = fmt"{RootPrefix} e={exampleTree.rootEntry.eroot} l={exampleTree.rootEntry.lroot} seq={exampleTree.rootEntry.seqNo} sig={expectedSig}"
      testSecKey = PrivateKey.fromHex(secKeyHex).get()
      testPubKey = testSecKey.toPublicKey()

    var tree = exampleTree

    let
      signRes = signTree(tree, testSecKey)
    check:
      signRes.isOk()
      tree.rootEntry.signature.len == SkRawRecoverableSignatureSize # 65 bytes

    # Verify signature
    let
      sigHash = hashableContent(tree.rootEntry)
      sig = SignatureNR.fromRaw(tree.rootEntry.signature)

    check:
      sig.isOk()
      verify(sig = sig[],
             msg = sigHash,
             key = testPubKey)

    # Check TXT record
    check:
      tree.rootEntry.toTXTRecord().get() == expectedTXT
