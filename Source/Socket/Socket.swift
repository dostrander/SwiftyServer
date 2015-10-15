//
//  Socket.swift
//
//
//  Created by Derek Ostrander on 10/11/15.
//
//

import Darwin

// MARK: Constants -

let LOCALHOST: String = "0.0.0.0"

// MARK: Types -

typealias SocketAddress = sockaddr
typealias SocketAddressInternet = sockaddr_in
typealias AddressInfo = addrinfo
typealias Spawn = (FileDescriptor, String, TCPPort) -> (Socket)

// MARK: Errors -

enum HostError : BaseError {

    case NetError(err: String, reason: String)

    var errorDescription: String {

        switch self {

        case NetError(err: let err, reason: let reason):
            return "\(err) -- \(reason)"
        }
    }
}

// MARK: Type Extensions -

extension SocketAddressInternet {

    static var size: Int {

        return sizeof(SocketAddressInternet)
    }

    static func Zeroed() -> SocketAddressInternet {

        return SocketAddressInternet(
            sin_len: 0,
            sin_family: 0,
            sin_port: 0,
            sin_addr: in_addr(s_addr: 0),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    static func InternetAddress(address: String, _ port: TCPPort) -> SocketAddressInternet {

        return SocketAddressInternet(
            sin_len: __uint8_t(sizeof(sockaddr_in)),
            sin_family: sa_family_t(AF_INET),
            sin_port: port.hton(),
            sin_addr: in_addr(s_addr: inet_addr(address)),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    static func InternetAddress(inout address: SocketAddress) -> SocketAddressInternet {

        var addressIn = SocketAddressInternet.Zeroed()
        memcpy(&addressIn, &address, SocketAddressInternet.size)
        return addressIn
    }

    static func Address(address: String, _ port: TCPPort) -> SocketAddress {

        var addressIn = InternetAddress(address, port)
        var address = SocketAddress.Zeroed()

        memcpy(&address, &addressIn, sizeof(SocketAddressInternet))

        return address
    }
}

extension SocketAddress {

    static var size: Int {
        return sizeof(SocketAddress)
    }

    static func Zeroed() -> SocketAddress {
        return SocketAddress(
            sa_len: 0,
            sa_family: 0,
            sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    mutating func NameComponents() throws -> (String, TCPPort) {
        var addressIn = SocketAddressInternet.InternetAddress(&self)
        var addressCString = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
        guard inet_ntop(AF_INET, &addressIn.sin_addr.s_addr, &addressCString, socklen_t(INET_ADDRSTRLEN)) != nil else {

            throw POSIXError.SystemError(err: "inet_ntop() failed", errno: errno)

        }

        let port = addressIn.sin_port
        guard let addressString = String.fromCString(addressCString) else {

            throw HostError.NetError(err: "Could not get IP address from SocketAddress", reason: "CString not convertible to String")

        }

        return (addressString, port)
        
    }
}

extension AddressInfo {

    static func TCPStreamInHints() -> AddressInfo {
        return AddressInfo(
            ai_flags: 0,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
    }
}

// MARK: Connectable -

protocol Connectable {

    // Vars
    var fd: FileDescriptor { get }
    var port: TCPPort { get }

    // Operations
    func connect(address: String, _ port: TCPPort) throws
    func bind(address: String, port: TCPPort) throws
    func listen(maxConnections: Int) throws
    func accept(spawn: Spawn) throws -> Socket
    func release()
}

// MARK: Socket -

class Socket : Connectable {

    let fd: FileDescriptor
    let port: TCPPort
    let address: String

    init(_ fd: FileDescriptor, _ address: String, _ port: TCPPort) {

        // Init vars
        self.fd = fd
        self.address = address
        self.port = port
    }

    convenience init() {

        // Invalid socket results
        self.init(-1, LOCALHOST, 0)
    }

    convenience init(_ port: TCPPort) throws {

        // Get correct values to init
        let address = LOCALHOST
        let fd = socket(AF_INET, SOCK_STREAM, 0)

        guard fd > 0 else {

            throw POSIXError.SystemError(err: "socket() failed", errno: errno)
        }

        // Init vars
        self.init(fd, address, port)

        log("Created socket -- \(self.fd)")

        // Setup for Stream Server implementation
        try applyOptions(.NoSigPipe, .ReuseAddress)
        try bind(self.address, port: self.port)
        try listen(20)
    }

    deinit {

        // Release the socket when it's no longer needed
        release()
    }
}

// MARK: Helpers -

extension Socket {

    static func DNSHostAddresses(address: String, port: TCPPort) throws -> [SocketAddress] {

        // Get host addrinfo for A Streamed, Internet, TCP socket
        var hints = AddressInfo.TCPStreamInHints()

        // Get Address Info
        var results = UnsafeMutablePointer<AddressInfo>()
        guard getaddrinfo(address, String(port), &hints, &results) > 0 else {

            throw POSIXError.SystemError(err: "getaddrinfo() failed", errno: errno)
        }
        defer { freeaddrinfo(results) }

        // Get Addresses from info
        return UnsafeBufferPointer(start: results, count: sizeof(AddressInfo)).map { return $0.ai_addr.memory }
    }
}

// MARK: Options -

extension Socket {

    enum Option : CustomStringConvertible {

        case ReuseAddress
        case NoSigPipe

        var description: String {

            switch self {

            case .NoSigPipe:
                return ".NoSigPipe"
            case .ReuseAddress:
                return ".ReuseAddress"
            }

        }

        var value: Int32 {

            switch self {

            case .NoSigPipe:
                return SO_NOSIGPIPE
            case .ReuseAddress:
                return SO_REUSEADDR
            }
        }

        enum Error : BaseError {

            case SetOption(err: POSIXError, opt: Option)

            var errorDescription: String {

                switch self {

                case .SetOption(err: let err, opt: let opt):
                    return "Setting option \(opt) -- \(err)"
                }
            }
        }
    }

    func applyOptions(options: Option...) throws {

        var value: Int32 = 1

        for option in options {

            guard setsockopt(fd, SOL_SOCKET, option.value, &value, socklen_t(sizeof(Int32))) >= 0
                else {
                    
                    let err = Option.Error.SetOption(err: POSIXError.SystemError(err: "setsockopt() failed", errno: errno), opt: option)
                    error("\(err)")
                    throw err
            }
        }

    }
}

// MARK: Operations -

// TODO: THIS CAN BE WAY BETTER
// MAYBE
//    enum Operation {
//        case Connect(address: String)
//        case Bind(address: String)
//        case Listen(maxConnections: Int)
//        case Accept(spawn: Spawn)
//    }

extension Socket {

    func connect(address: String, _ port: TCPPort) throws {

        let addresses = try Socket.DNSHostAddresses(address, port: port)
        guard addresses.count > 0 else {

            throw HostError.NetError(err: "DNS solve error", reason: "No addresses returned from DNS query")
        }

        var addr = addresses.first!

        guard Darwin.connect(fd, &addr, socklen_t(sizeof(SocketAddressInternet))) >= 0 else {

            throw POSIXError.SystemError(err: "connect() failed", errno: errno)
        }

        log("Connected to \(address):\(port)")
    }
    
    func bind(address: String, port: TCPPort) throws {

        var addr = SocketAddressInternet.Address(address, port)
        guard Darwin.bind(fd, &addr, socklen_t(SocketAddressInternet.size)) >= 0 else {

            throw POSIXError.SystemError(err: "bind() failed", errno: errno)
        }

        log("Bound to \(address):\(port)")
    }
    
    func listen(maxConnections: Int) throws {

        guard Darwin.listen(fd, Int32(maxConnections)) >= 0 else {

            throw POSIXError.SystemError(err: "listen() failed", errno: errno)
        }

        log("Listening with \(maxConnections) Max Connections")
    }
    
    func accept(spawn: Spawn) throws -> Socket {

        var address = SocketAddress.Zeroed()
        var length = socklen_t(SocketAddress.size)

        let clientFd = Darwin.accept(fd, &address, &length)
        guard clientFd > 0 else {

            throw POSIXError.SystemError(err: "accept() failed", errno: errno)
        }

        let (addressString, port) = try address.NameComponents()
        log("Accepted client \(addressString):\(port) -- \(clientFd)")

        return spawn(clientFd, addressString, port)
    }
    
    func release() {

        log("Releasing Socket -- \(fd)")
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }
}
