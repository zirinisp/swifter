//
//  Errno.swift
//  Swifter
//
//  Created by Damian Kolakowski on 13/07/16.
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

public class Errno {
    
    public class func description() -> String {
        return String.fromCString(UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
    }
}
