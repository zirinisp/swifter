//
//  AsyncServerSocket.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum AsyncServerSocketError: ErrorProtocol {
    case AsyncError(String)
    case SocketCreationFailed(String)
    case SocketSetReUseAddrFailed(String)
    case SocketBindFailed(String)
    case SocketListenFailed(String)
    case SocketWriteFailed(String)
    case SocketGetPeerNameFailed(String)
    case SocketConvertingPeerNameFailed
    case SocketGetNameInfoFailed(String)
    case SocketAcceptFailed(String)
    case SocketRecvFailed(String)
}

public protocol AsyncServerSocketCallback {
    func clientConnected(socketFileDescriptor: Int32)
    func clientDisconnected(socketFileDescriptor: Int32)
    func clientData(socketFileDescriptor: Int32, _ data: ArraySlice<UInt8>)
}

public protocol AsyncServerSocket {
    init(port: in_port_t) throws
    func run(callback: AsyncServerSocketCallback) throws 
}

public func lastErrnoDetails() -> String {
    return String(cString: UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
}