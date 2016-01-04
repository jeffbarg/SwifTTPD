import Foundation

#if os(Linux)
import SwiftGlibc
#else
import Darwin
#endif

let INADDR_ANY: UInt32 = UInt32(0)

public class Socket {

    public var port: UInt16
    private var socketDescriptor: Int32!

    private var atEof: Bool

    init(port: UInt16) {
        // Initialize Internet Address (IPV4)
        var name: sockaddr_in = sockaddr_in(
            sin_len: 0,
            sin_family: sa_family_t(AF_INET),
            sin_port: in_port_t(port.bigEndian),
            sin_addr: in_addr(
                s_addr: INADDR_ANY
            ),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        var sock_addr : sockaddr = sockaddr() // Convert to sockaddr
        memcpy(&sock_addr, &name, Int(sizeof(sockaddr_in)))

        // Initialize TCP Socket
        #if os(Linux)
        socketDescriptor = SwiftGLibc.socket(PF_INET, SOCK_STREAM, 0);
        #else
        socketDescriptor = Darwin.socket(PF_INET, SOCK_STREAM, 0);
        #endif

        if (socketDescriptor == -1) {
            perror("socket")
            exit(1)
        }

        // Bind socket to socket name
        #if os(Linux)
        let bindResult = SwiftGLibc.bind(
            socketDescriptor,
            &sock_addr,
            UInt32(sizeofValue(name))
        )
        #else
        let bindResult = Darwin.bind(
            socketDescriptor,
            &sock_addr,
            UInt32(sizeofValue(name))
        )
        #endif

        if (bindResult < 0) {
            perror("bind")
            exit(1)
        }

        self.port = port

        var namelen: socklen_t = UInt32(sizeofValue(name));
        if (Darwin.getsockname(socketDescriptor, &sock_addr, &namelen) == -1) {
            perror("getsockname")
            exit(1)
        }

        // Set port
        memcpy(&name, &sock_addr, Int(sizeof(sockaddr_in)))
        self.port = name.sin_port.bigEndian

        atEof = false
    }

    init(descriptor: Int32) {
        self.socketDescriptor = descriptor
        self.port = 0

        atEof = false
    }

    deinit {
        self.close()
    }

    public func listen() {
        if (Darwin.listen(socketDescriptor, 5) < 0) {
            perror("listen")
            exit(1)
        }
    }

    public func send(message: String) {
         var buf: [UInt8]
         buf = [UInt8](message.utf8)

         #if os(Linux)
         if (SwiftGLibc.send(socketDescriptor, buf, buf.count, 0) < 0) {
            perror("send")
         }
         #else
         if (Darwin.send(socketDescriptor, buf, buf.count, 0) < 0) {
            perror("send")
         }
         #endif
    }

    public func accept() -> Socket {
        var clientName : sockaddr = sockaddr()
        var clientNameLen : socklen_t = UInt32(sizeofValue(clientName))

        var inputSocket: Int32

        #if os(Linux)
        inputSocket = SwiftGLibc.accept(
            socketDescriptor,
            &clientName,
            &clientNameLen
        )
        #else
        inputSocket = Darwin.accept(
            socketDescriptor,
            &clientName,
            &clientNameLen
        )
        #endif

        if inputSocket == -1 {
           perror("accept")
           exit(1) 
        }

        return Socket(descriptor: inputSocket)
    }

    /**********************************************************************/
    /* Get a line from a socket, whether the line ends in a newline,
     * carriage return, or a CRLF combination.  Terminates the string read
     * with a null character.  If no newline indicator is found before the
     * end of the buffer, the string is terminated with a null.  If any of
     * the above three line terminators is read, the last character of the
     * string will be a linefeed and the string will be terminated with a
     * null character.
     * Parameters: the socket descriptor
     *             the buffer to save the data in
     *             the size of the buffer
     * Returns: the number of bytes stored (excluding null) */
    /**********************************************************************/
    public func nextLine() -> String? {
        var c: UInt8 = 0
        var n: Int = 0

        let newline: UInt8 = Array("\n".utf8)[0]
        let returncarriage: UInt8 = Array("\r".utf8)[0]

        var returnString: String = ""

        if (atEof) {
            return nil
        }

        while (c != newline) {
            // Read from socket
            #if os(Linux)
            n = SwiftGLibc.recv(socketDescriptor, &c, 1, 0)
            #else
            n = Darwin.recv(socketDescriptor, &c, 1, 0)
            #endif

            guard n > 0 else {
                c = newline
                continue
            }

            if (c == returncarriage) {
                #if os(Linux)
                n = SwiftGLibc.recv(socketDescriptor, &c, 1, MSG_PEEK)
                #else
                n = Darwin.recv(socketDescriptor, &c, 1, MSG_PEEK)
                #endif

                if ((n > 0) && (c == newline)) {
                    #if os(Linux)
                    SwiftGLibc.recv(socketDescriptor, &c, 1, 0)
                    #else
                    Darwin.recv(socketDescriptor, &c, 1, 0)
                    #endif
                }
                else {
                    c = newline
                }
            }

            returnString = returnString + String(Character(UnicodeScalar(UInt32(c))))
        }

        if (returnString == "\n") {
            atEof = true
        }
        return returnString
    }

    private func rewind() {
        atEof = false
    }

    public func close() {
        if let sd = socketDescriptor {
            #if os(Linux)
            SwiftGLibc.close(sd)
            #else
            Darwin.close(sd)
            #endif

            socketDescriptor = nil
        }
    }

}
