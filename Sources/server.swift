import Foundation

#if os(Linux)
import SwiftGlibc
#else
import Darwin
#endif

public class Server {
    var baseURL: String

    let SERVER_STRING = "Server: swifttpd/0.1.0\r\n"

    var serverSocket: Socket
    var port: UInt16

    init(port : UInt16 = 3000, rootDirectory: String) {
        serverSocket = Socket(port: port)
        serverSocket.listen()
        self.port = serverSocket.port
        self.baseURL = rootDirectory
    }

    deinit {

    }

    private func acceptRequest(requestSocket: Socket) {

        let requestString = requestSocket.nextLine()!
        let requestComponents = requestString.componentsSeparatedByString(" ")
        // let method = requestComponents[0]
        let urlStr = requestComponents[1]
        
        guard let urlComponents = NSURLComponents(string: urlStr) else {
            perror("components")
            exit(1)
        }

        guard let path = urlComponents.path else {
            perror("components path")
            exit(1)
        }

        serveFile(requestSocket: requestSocket, path: path)
        requestSocket.close()
    }

    private func serveFile(requestSocket requestSocket: Socket, path: String) {
        // Clear headers
        while (requestSocket.nextLine() != nil) {}

        let fullPath = NSString(string: baseURL).stringByAppendingPathComponent(path)

        if let reader : StreamReader = StreamReader(path: fullPath) {
            headers(requestSocket: requestSocket, path: path)
            cat(requestSocket: requestSocket, reader: reader)
        } else {
            notFound(requestSocket: requestSocket)
        }
    }

    private func notFound(requestSocket requestSocket: Socket) {
         requestSocket.send("HTTP/1.0 404 NOT FOUND\r\n")
         requestSocket.send(SERVER_STRING)
         requestSocket.send("Content-Type: text/html\r\n")
         requestSocket.send("\r\n")
         requestSocket.send("<HTML><TITLE>Not Found</TITLE>\r\n")
         requestSocket.send("<BODY><P>The server could not fulfill\r\n")
         requestSocket.send("your request because the resource specified\r\n")
         requestSocket.send("is unavailable or nonexistent.\r\n")
         requestSocket.send("</BODY></HTML>\r\n")
    }

    private func headers(requestSocket requestSocket: Socket, path: String) {
        requestSocket.send("HTTP/1.0 200 OK\r\n")
        requestSocket.send(SERVER_STRING)
        requestSocket.send("Content-Type: text/html\r\n")
        requestSocket.send("\r\n")
    }

    private func cat(requestSocket requestSocket: Socket, reader: StreamReader) {        
        while let line = reader.nextLine() {
            requestSocket.send(line)
        }
    }

    public func serveForever() {
        while (true) {
            let inputSocket = serverSocket.accept()
            
            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
            dispatch_async(backgroundQueue, {
                self.acceptRequest(inputSocket)
            })
        }
    }
}
