//
//  OSXAsyncServerSocket.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum KernelQueueError: ErrorProtocol {
    case CreateError(String)
    case ActionError(String)
    case WaitError(String)
}

private class KernelQueue {
    
    private let kernelQueue: Int32
    
    init() throws {
        kernelQueue = kqueue()
        if kernelQueue == -1 {
            throw KernelQueueError.CreateError(lastErrnoDetails())
        }
    }
    
    deinit {
        close(kernelQueue)
    }
    
    func add(descriptor: Int32) throws {
        try performAction(descriptor, EV_ADD)
    }
    
    func delete(descriptor: Int32) throws {
        try performAction(descriptor, EV_DELETE)
    }
    
    func run(callback: (kevent throws -> Void)) throws {
        
        typealias KEVENT = kevent
        var eventlist = [KEVENT](repeating: kevent(), count: 32)
        
        while true {
        
            let numberOfEvents = Int(kevent(kernelQueue, nil, 0, &eventlist, 32, nil))
            
            if numberOfEvents == -1 { throw KernelQueueError.WaitError(lastErrnoDetails()) }
            
            for index in 0..<numberOfEvents {
                try callback(eventlist[index])
            }
        }
    }
    
    private func performAction(descriptor: Int32, _ action: Int32) throws {
        var event = kevent(ident: UInt(descriptor), filter: Int16(EVFILT_READ), flags: UInt16(action), fflags: 0, data: 0, udata: nil)
        if kevent(kernelQueue, &event, 1, nil, 0, nil) == -1 {
            throw KernelQueueError.ActionError(lastErrnoDetails())
        }
    }
}

public class OSXAsyncServerSocket: AsyncServerSocket {
    
    private let serverSocket: Int32
    private let kernelQueue: KernelQueue
    
    public required init(port: in_port_t) throws {
        
        kernelQueue = try KernelQueue()
        
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        
        if serverSocket == -1 { throw AsyncServerSocketError.SocketCreationFailed(lastErrnoDetails()) }
        
        var reuseAddrFlag: Int32 = 1
        if setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddrFlag, socklen_t(sizeof(Int32))) == -1 {
            throw AsyncServerSocketError.SocketSetReUseAddrFailed(OSXAsyncServerSocket.grabErrnoAndRelease(serverSocket))
        }
        
        var noSigPipe: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(sizeof(Int32)))
        
        let netPort = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        
        var addr = sockaddr_in(sin_len: __uint8_t(sizeof(sockaddr_in)), sin_family: sa_family_t(AF_INET),
            sin_port: netPort, sin_addr: in_addr(s_addr: inet_addr("0.0.0.0")), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeof(sockaddr_in)))
        
        if bind(serverSocket, &bind_addr, socklen_t(sizeof(sockaddr_in))) == -1 {
            throw AsyncServerSocketError.SocketBindFailed(OSXAsyncServerSocket.grabErrnoAndRelease(serverSocket))
        }
        
        if listen(serverSocket, SOMAXCONN) == -1 {
            throw AsyncServerSocketError.SocketListenFailed(OSXAsyncServerSocket.grabErrnoAndRelease(serverSocket))
        }
    }
    
    deinit {
        OSXAsyncServerSocket.release(serverSocket)
    }
    
    private static func grabErrnoAndRelease(fileDescriptior: Int32) -> String {
        let errnoDetails = lastErrnoDetails()
        release(fileDescriptior)
        return errnoDetails
    }
    
    private static func release(fileDescriptior: Int32) {
        Darwin.shutdown(fileDescriptior, SHUT_RDWR)
        close(fileDescriptior)
    }
    
    public func run(callback: AsyncServerSocketCallback) throws {
        
        try kernelQueue.add(serverSocket)
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        
        try kernelQueue.run() { event in
            
            if (event.ident == UInt(self.serverSocket)) {
                let client = accept(Int32(event.ident), nil, nil)
                if client == -1 {
                    throw AsyncServerSocketError.SocketAcceptFailed(OSXAsyncServerSocket.grabErrnoAndRelease(self.serverSocket))
                }
                try self.kernelQueue.add(client)
                callback.clientConnected(client)
                return
            }
            
            if Int32(event.flags) & EV_EOF != 0 || Int32(event.flags) & EV_ERROR != 0 {
                try self.kernelQueue.delete(Int32(event.ident))
                callback.clientDisconnected(Int32(event.ident))
                return
            }
            
            if Int32(event.filter) == EVFILT_READ {
                let n = recv(Int32(event.ident), &buffer, min(buffer.count, event.data), 0)
                if n > 0 {
                    callback.clientData(Int32(event.ident), buffer[0..<n])
                }
                return
            }
        }
    }
}

