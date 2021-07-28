import
  std/tables,
  ../discovery/dnsdisc/tree

# Create sample tree from EIP-1459
var exampleRecords* = initTable[string, string]()
exampleRecords["nodes.example.org"] = "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"
exampleRecords["C7HRFPF3BLGF3YR4DY5KX3SMBE.nodes.example.org"] = "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
exampleRecords["JWXYDBPXYWG6FX3GMDIBFA6CJ4.nodes.example.org"] = "enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24"
exampleRecords["2XS2367YHAXJFGLZHVAWLQD4ZY.nodes.example.org"] = "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA"
exampleRecords["H4FHT4B454P6UXFD7JCYQ5PWDY.nodes.example.org"] = "enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI"
exampleRecords["MHTDO6TMUBRIA2XWG5LUDACK24.nodes.example.org"] = "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o"

let exampleTree* = Tree(
                    rootEntry: parseRootEntry(exampleRecords["nodes.example.org"]).get(),
                    entries: @[parseSubtreeEntry(exampleRecords["C7HRFPF3BLGF3YR4DY5KX3SMBE.nodes.example.org"]).get(),
                               parseSubtreeEntry(exampleRecords["JWXYDBPXYWG6FX3GMDIBFA6CJ4.nodes.example.org"]).get(),
                               parseSubtreeEntry(exampleRecords["2XS2367YHAXJFGLZHVAWLQD4ZY.nodes.example.org"]).get(),
                               parseSubtreeEntry(exampleRecords["H4FHT4B454P6UXFD7JCYQ5PWDY.nodes.example.org"]).get(),
                               parseSubtreeEntry(exampleRecords["MHTDO6TMUBRIA2XWG5LUDACK24.nodes.example.org"]).get()])