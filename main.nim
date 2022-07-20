import std/asynchttpserver
import std/asyncdispatch
import std/tables
import std/json
import std/strutils
import std/osproc

proc serveStaticFile(req: Request) {.async.} = 
    try:
        let filename = req.url.path.split('/')[1]
        let extension = '.' & filename.split(".")[1]
        let mimes = parseJson(readFile("./extmime.json"))
        let mimetype = mimes[extension].getStr()
        var file = readFile("./static/" & filename)
        await req.respond(Http200, file, {"Content-Type": mimetype}.newHttpHeaders())
    except:
        await req.respond(Http404, "Not Found")

type Server = ref object of RootObj
    hostname: string
    port: int
    routes: Table[string, proc (req: Request) {.async.}]
method get(this: Server, route: string, cb: proc (req: Request) {.async.}) =
    this.routes[route] = cb
method start(this: Server) {.async.} = 
    var server = newAsyncHttpServer()
    
    proc cb(req: Request) {.async, gcsafe.} =
        if this.routes.hasKey(req.url.path):
            await this.routes[req.url.path](req)
        else:
            await serveStaticFile(req)

    server.listen(Port(0))
    let port = server.getPort
    let host = "localhost:" & $port.uint16 & "/"
    discard execProcess("open http://" & host)
    while true:
        if server.shouldAcceptRequest():
            await server.acceptRequest(cb)
        else:
            await sleepAsync(500)


proc main {.async.} =
    var app = Server(hostname: "localhost", port: 8080)
    app.get("/", proc (req: Request) {.async.} = 
        let msg = %* {"msg": "Hellooo"}
        await req.respond(Http200, $msg, {"Content-Type": "application/json"}.newHttpHeaders()))
    await app.start()

waitFor main()