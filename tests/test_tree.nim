{.used.}

import
  std/strutils,
  testutils/unittests,
  chronos,
  stew/[base64],
  results,
  ../dnsdisc/tree

procSuite "Test DNS Discovery: Merkle Tree":
  asyncTest "Parse root entry":
    # Expected case
    let entryRes = parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")

    check:
      entryRes.isOk()
      entryRes[].eroot == "JWXYDBPXYWG6FX3GMDIBFA6CJ4"
      entryRes[].lroot == "C7HRFPF3BLGF3YR4DY5KX3SMBE"
      entryRes[].seqNo == 1
      entryRes[].signature == Base64Url.decode("o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")

    # Invalid cases
    check:
      # Invalid syntax: gibberish
      parseRootEntry("gibberish")
                    .error()
                    .contains("Invalid syntax")

      # Invalid syntax: no space
      parseRootEntry("enrtree-root:v1e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")
                    .error()
                    .contains("Invalid syntax")

      # Invalid child: eroot too short
      parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")
                    .error()
                    .contains("Invalid child")

      # Invalid child: lroot newline
      parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SM\n\r seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")
                    .error()
                    .contains("Invalid child")

      # Invalid signature
      parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463g")
                    .error()
                    .contains("Invalid signature")

  asyncTest "Parse branch entry":
    # Expected case
    let entryRes = parseBranchEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24")

    check:
      entryRes.isOk()
      entryRes[].children.len == 3
      entryRes[].children.contains("2XS2367YHAXJFGLZHVAWLQD4ZY")
      entryRes[].children.contains("H4FHT4B454P6UXFD7JCYQ5PWDY")
      entryRes[].children.contains("MHTDO6TMUBRIA2XWG5LUDACK24")

    # Invalid cases
    check:
      # Invalid syntax: gibberish
      parseBranchEntry("gibberish")
                      .error()
                      .contains("Invalid syntax")

      # Invalid syntax: invalid space
      parseBranchEntry("enrtree-branch :2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24")
                      .error()
                      .contains("Invalid syntax")

      # Invalid child: invalid first entry - leading space
      parseBranchEntry("enrtree-branch: 2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24")
                      .error()
                      .contains("Invalid child")

      # Invalid child: invalid middle entry - too short
      parseBranchEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWD,MHTDO6TMUBRIA2XWG5LUDACK24")
                      .error()
                      .contains("Invalid child")

      # Invalid child: invalid last entry - trailing space
      parseBranchEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24 ")
                      .error()
                      .contains("Invalid child")

  asyncTest "Parse ENR entry":
    # Expected case
    let entryRes = parseEnrEntry("enr:-IS4QHCYrYZbAKWCBRlAy5zzaDZXJBGkcnh4MHcBFZntXNFrdvJjX04jRzjzCBOonrkTfj499SZuOh8R33Ls8RRcy5wBgmlkgnY0gmlwhH8AAAGJc2VjcDI1NmsxoQPKY0yuDUmstAHYpMa2_oxVtw0RW_QAdpzBQA8yWM0xOIN1ZHCCdl8")

    check:
      entryRes.isOk()
      $(entryRes[].record) == """(1, id: "v4", ip: 127.0.0.1, secp256k1: 0x03CA634CAE0D49ACB401D8A4C6B6FE8C55B70D115BF400769CC1400F3258CD3138, udp: 30303)"""

    # Invalid cases
    check:
      # Invalid syntax: gibberish
      parseEnrEntry("gibberish")
                    .error()
                    .contains("Invalid syntax")

      # Invalid syntax: invalid prefix
      parseEnrEntry("enr=-IS4QHCYrYZbAKWCBRlAy5zzaDZXJBGkcnh4MHcBFZntXNFrdvJjX04jRzjzCBOonrkTfj499SZuOh8R33Ls8RRcy5wBgmlkgnY0gmlwhH8AAAGJc2VjcDI1NmsxoQPKY0yuDUmstAHYpMa2_oxVtw0RW_QAdpzBQA8yWM0xOIN1ZHCCdl8")
                    .error()
                    .contains("Invalid syntax")

      # Invalid syntax
      parseEnrEntry("enr:-IS4QHCYrYZbAKWCBRlAy5zzaDZXJBGkcnh4MHcBFZntXNFrdvJjX04jRzjzCBOOnrkTfj499SZuOh8R33Ls8RRcy5wBgmlkgnY0gmlwhH8AAAGJc2VjcDI1NmsxoQPKY0yuDUmstAHYpMa2_oxVtw0RW_QAdpzBQA8yWM0xOIN1ZHCCdl8")
                    .error()
                    .contains("Invalid signature")

  asyncTest "Parse link entry":
    # Expected case
    let entryRes = parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org")

    check:
      entryRes.isOk()
      entryRes[].str == "AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
      entryRes[].domain == "morenodes.example.org"
      entryRes[].pubKey.toAddress() == "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b"

    # Invalid cases
    check:
      # Invalid syntax: gibberish
      parseLinkEntry("gibberish")
                     .error()
                     .contains("Invalid syntax")

      # Invalid syntax: invalid prefix
      parseLinkEntry("enr-tree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org")
                     .error()
                     .contains("Invalid syntax")

      # Invalid syntax: invalid @domain syntax
      parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2#morenodes.example.org")
                     .error()
                     .contains("Invalid syntax")

      # Invalid public key: invalid base32
      parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDq5FDPRT2@morenodes.example.org")
                     .error()
                     .contains("Invalid public key")

      # Invalid public key: invalid key
      parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5DPRT2@morenodes.example.org")
                     .error()
                     .contains("Invalid public key")

  asyncTest "Parse generic subtree entry":
    let
      expectedBranch = parseBranchEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24").tryGet()
      expectedEnr = parseEnrEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet()
      expectedLink = parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org").tryGet()

    # Expected cases
    check:
      # Branch entry
      expectedBranch == parseSubtreeEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24")
                                         .tryGet()
                                         .branchEntry

      # Enr entry
      expectedEnr == parseSubtreeEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA")
                                      .tryGet()
                                      .enrEntry
      # Link entry
      expectedLink == parseSubtreeEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org")
                                       .tryGet()
                                       .linkEntry

    # Invalid cases
    check:
      # Not a subtree entry
      parseSubtreeEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA")
                       .error()
                       .contains("Unexpected subtree entry type")

      # Subtree entry invalid: Invalid child
      parseSubtreeEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4 ,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24")
                       .error()
                       .contains("Invalid child")


  asyncTest "Access tree entries":
    # Build the example tree from EIP-1459
    var
      testTree = Tree()
      entries: seq[SubtreeEntry]

    testTree.rootEntry = parseRootEntry("enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA").tryGet()
    testTree.entries.add(parseSubtreeEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org").tryGet())
    testTree.entries.add(parseSubtreeEntry("enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24").tryGet())
    testTree.entries.add(parseSubtreeEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet())
    testTree.entries.add(parseSubtreeEntry("enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI").tryGet())
    testTree.entries.add(parseSubtreeEntry("enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o").tryGet())

    # Test accessing node entries

    let nodes = testTree.getNodes()

    check:
      nodes.len == 3
      nodes.contains(parseEnrEntry("enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA").tryGet())
      nodes.contains(parseEnrEntry("enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI").tryGet())
      nodes.contains(parseEnrEntry("enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o").tryGet())


    # Test accessing link entries

    let links = testTree.getLinks()

    check:
      links.len == 1
      links.contains(parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org").tryGet())
