import
  std/tables,
  ../dnsdisc/tree

# Example tree constants, used in multiple tests
const
  # Domain
  Domain* = "nodes.example.org"
  LinkSubdomain* = "C7HRFPF3BLGF3YR4DY5KX3SMBE"
  BranchSubdomain* = "JWXYDBPXYWG6FX3GMDIBFA6CJ4"
  Enr1Subdomain* = "2XS2367YHAXJFGLZHVAWLQD4ZY"
  Enr2Subdomain* = "H4FHT4B454P6UXFD7JCYQ5PWDY"
  Enr3Subdomain* = "MHTDO6TMUBRIA2XWG5LUDACK24"
  # Records
  RootTxt* = "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"
  LinkTxt* = "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@morenodes.example.org"
  BranchTxt* = "enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,H4FHT4B454P6UXFD7JCYQ5PWDY,MHTDO6TMUBRIA2XWG5LUDACK24"
  Enr1Txt* = "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA"
  Enr2Txt* = "enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI"
  Enr3Txt* = "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o"

# Create sample tree from EIP-1459
func initExampleRecords(): Table[string, string] =
  var exampleRecords = initTable[string, string]()

  exampleRecords[Domain] = RootTxt
  exampleRecords[LinkSubdomain & "." & Domain] = LinkTxt
  exampleRecords[BranchSubdomain & "." & Domain] = BranchTxt
  exampleRecords[Enr1Subdomain & "." & Domain] = Enr1Txt
  exampleRecords[Enr2Subdomain & "." & Domain] = Enr2Txt
  exampleRecords[Enr3Subdomain & "." & Domain] = Enr3Txt

  return exampleRecords

# Exported example tree variables, used in multiple tests
let
  exampleRecords* = initExampleRecords()

  exampleRoot* = parseRootEntry(RootTxt).get()

  exampleLink* = parseSubtreeEntry(LinkTxt).get()

  exampleBranch* = parseSubtreeEntry(BranchTxt).get()

  exampleEnr1* = parseSubtreeEntry(Enr1Txt).get()
  exampleEnr2* = parseSubtreeEntry(Enr2Txt).get()
  exampleEnr3* = parseSubtreeEntry(Enr3Txt).get()

  exampleTree* = Tree(rootEntry: exampleRoot,
                      entries: @[exampleLink,
                                 exampleBranch,
                                 exampleEnr1,
                                 exampleEnr2,
                                 exampleEnr3])
