{.used.}

import
  std/strutils,
  chronos,
  stew/base64,
  testutils/unittests,
  ../discovery/dnsdisc/[tree, client]

procSuite "Test DNS Discovery: Client":
  asyncTest "Resolve root":
    ## This tests resolving a root TXT entry at a given domain location,
    ## parsing the entry and verifying the signature.
    
    # Expected case
    
    proc resolver(domain: string): Future[string] {.async.} =
      return "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"

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


