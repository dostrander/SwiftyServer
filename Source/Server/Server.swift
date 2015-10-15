//
//  Server.swift
//  SwiftyServer
//
//  Created by Derek Ostrander on 10/13/15.
//  Copyright © 2015 Derek Ostrander. All rights reserved.
//

import Darwin

// MARK: Server - 

public protocol Server {

    func start()

    func stop()
}

// MARK: HTTPServer -

public struct HTTPServer {

    var socket: Socket

    public init(_ port: TCPPort) {

        do {

            self.socket = try Socket(port)
        }
        catch let err {

            fatalError("\(err)")
        }
    }
}

// MARK: HTTPServer - Server Protocol -

extension HTTPServer : Server {

    public func start() {

        log("Server Starting...")

        // Break if client becomes nil
        while true {

            // Accept the connection and spawn a socket
            // guard against nil client socket
            guard let client = try? self.socket.accept({ (clientFd, address, port) in return Socket(clientFd, address, port) }) else {

                // kill any other resources
                stop()
                break
            }

            // NOOP for now, just log it
            log("\(client)")
        }
    }

    public func stop() {

        // NOOP for now, just log it
        log("Stopping Server...")
    }
}

