//
//  Error.swift
//  SwiftyServer
//
//  Created by Derek Ostrander on 10/11/15.
//  Copyright © 2015 Derek Ostrander. All rights reserved.
//

import Darwin

protocol BaseError : CustomStringConvertible, ErrorType {

    var errorDescription: String { get }

    func Log()

}

extension BaseError {

    var description: String {
        
        return "\(errorDescription)"
    }

    func Log() {

        error("\(self.description)")
    }

}
