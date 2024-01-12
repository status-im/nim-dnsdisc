{.push raises: [Defect].}

import
  std/tables,
  chronicles,
  json_rpc/rpcserver,
  stew/shims/net,
  stew/results,
  ./tree_creator

logScope:
  topics = "tree.creator.rpc"

proc installRpcApiHandlers(initTc: TreeCreator, rpcsrv: RpcServer) {.gcsafe.} =
  var tc = initTc # Create a mutable copy, to maintain memory safety
  
  rpcsrv.rpc("post_domain") do(domain: string) -> bool:
    debug "post_domain"
    tc.setDomain(domain)
    return true
  
  rpcsrv.rpc("get_domain") do() -> Option[string]:
    debug "get_domain"
    return tc.getDomain()

  rpcsrv.rpc("post_enr_entries") do(enrRecords: seq[string]) -> bool:
    debug "post_enr_entries"
    return tc.addEnrEntries(enrRecords)

  rpcsrv.rpc("post_link_entries") do(links: seq[string]) -> bool:
    debug "post_link_entries"
    return tc.addLinkEntries(links)

  rpcsrv.rpc("get_txt_records") do() -> Table[string, string]:
    debug "get_txt_records"
    let txts = tc.getTXTs().tryGet()
    return txts

  rpcsrv.rpc("get_public_key") do() -> string:
    debug "get_public_key"
    return tc.getPublicKey()

  rpcsrv.rpc("get_url") do() -> string:
    debug "get_url"
    let url = tc.getURL().tryGet()
    return url

proc startRpc*(tc: var TreeCreator, rpcIp: ValidIpAddress, rpcPort: Port)
  {.raises: [Defect, RpcBindError].} =
  info "Starting RPC server"
  let
    ta = initTAddress(rpcIp, rpcPort)
    rpcServer = newRpcHttpServer([ta])
  
  installRpcApiHandlers(tc, rpcServer)

  rpcServer.start()
  info "RPC Server started", ta
