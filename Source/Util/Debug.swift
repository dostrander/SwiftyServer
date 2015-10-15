//
//  SwiftyServer.swift
//  SwiftyServer
//
//  Created by Derek Ostrander on 10/11/15.
//  Copyright © 2015 Derek Ostrander. All rights reserved.
//

// MARK: Constants -

private let LOG = true
private let ERROR = true


// MARK: Debug Logging -

func log(str: String) {

    if LOG {

        print(str)
    }
}

func error(str: String) {

    if ERROR {

        log("ERROR: \(str)")
    }
}

@noreturn func kill(str: String) {

    error(str)
    fatalError(str)
}
