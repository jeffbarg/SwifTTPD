//
// Serve simply on port 3000
//

import Foundation

#if os(Linux)
import SwiftGlibc
#else
import Darwin
#endif

var port: UInt16
var rootDirectory: String

if Process.arguments.count > 1 {
    let argument = Process.arguments[1]
    if let _port = UInt16(argument) {
        port = _port
    } else {
        print("First argument should be a valid port number")
        exit(1)
    }
} else {
    port = 3000
}

if Process.arguments.count > 2 {
    rootDirectory = Process.arguments[2]
} else {
    rootDirectory = "/var/www/"
}

if Process.arguments.count > 3 {
    print("Too many arguments: use ./tinyhttpd PORT ROOT_DIRECTORY")
    exit(1)
}

var server: Server
server = Server(port: port, rootDirectory: rootDirectory)
server.serveForever()
