{.used.}

import
  chronos,
  testutils/unittests,
  ../discovery/dnsdisc/[tree, client]

procSuite "Test DNS Discovery: Client":
  asyncTest "Resolve root":
    
    proc resolver(domain: string): Future[string] {.async.} =
      return "enrtree-root:v1 e=JWXYDBPXYWG6FX3GMDIBFA6CJ4 l=C7HRFPF3BLGF3YR4DY5KX3SMBE seq=1 sig=o908WmNp7LibOfPsr4btQwatZJ5URBr2ZAuxvK4UWHlsB9sUOTJQaGAlLPVAhM__XJesCHxLISo94z5Z2a463gA"

    let loc = parseLinkEntry("enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@nodes.example.org").tryGet()
    
    echo repr(resolveRoot(resolver, loc))
