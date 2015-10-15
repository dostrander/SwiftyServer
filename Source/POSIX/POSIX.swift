//
//  POSIX.swift
//  SwiftyServer
//
//  Created by Derek Ostrander on 10/11/15.
//  Copyright © 2015 Derek Ostrander. All rights reserved.
//

import Darwin

// MARK: Types -

public typealias TCPPort = in_port_t
public typealias FileDescriptor = CInt

// MARK: HTON -

func isLittleEndian() -> Bool {

    return Int(OSHostByteOrder()) == OSLittleEndian
}

extension TCPPort {

    func hton() -> TCPPort {

        return isLittleEndian() ? _OSSwapInt16(self) : self
    }
}

// MARK: Error handling - 
// TODO: no real need for an enum

enum POSIXError : BaseError {

    case SystemError(err: String, errno: Int32)

    var errorNumber: Int32 {

        switch self {

        case .SystemError(_, errno: let num):
            return num
        }
    }

    var errorDescription: String {

        switch self {

        case .SystemError(err: let str, errno: let num):
            return "\(num) ). \(String.fromCString(strerror(errorNumber))) -- \(str)"
        }
    }
}