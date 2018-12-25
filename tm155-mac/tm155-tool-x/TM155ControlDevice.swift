//
//  TM155ControlDevice.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 23/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Foundation

enum TM155Error: Error {
    case mismatchedReply
    case sizeError
}

class TM155ControlDevice: HIDDevice {
    private class BulkRead {
        var request: (UInt8, [UInt8])
        var reply: [UInt8]
        var data: [UInt8]
        var nextPosition: Int = 0
        var onComplete: ([UInt8], [UInt8]) -> Void
        var onError: (Error) -> Void
        
        init(request: (UInt8, [UInt8]), size: Int, onComplete: @escaping ([UInt8], [UInt8]) -> Void, onError: @escaping (Error) -> Void) {
            self.request = request
            self.reply = []
            self.data = [UInt8].init(repeating: 0, count: size)
            self.onComplete = onComplete
            self.onError = onError
        }
    }
    private var bulkReadQueue: [BulkRead] = []
    
    func calculateChecksum(_ id: UInt8, _ data: [UInt8]) -> UInt8 {
        var work = UInt8(0xFF - id)
        for byte in data {
            work &-= byte
        }
        return work
    }
    
    func setCommand(id: UInt8, args: [UInt8]) throws {
        assert(args.count == 6)
        assert((id & 0x80) == 0)
        let cmd: [UInt8] = [id, args[0], args[1], args[2], args[3], args[4], args[5], calculateChecksum(id, args)]
        try setFeatureReport(cmd, id: 0)
    }
    
    func getCommand(id: UInt8, args: [UInt8]) throws -> [UInt8] {
        assert(args.count == 6)
        assert((id & 0x80) != 0)
        
        let cmd: [UInt8] = [id, args[0], args[1], args[2], args[3], args[4], args[5], calculateChecksum(id, args)]
        try setFeatureReport(cmd, id: 0)
        let reply = try getFeatureReport(id: 0)
        if reply[0] != id {
            throw TM155Error.mismatchedReply
        }
        return reply
    }
    
    func writeBulkData(id: UInt8, args: [UInt8], data: [UInt8]) throws {
        try setCommand(id: id, args: args)
        var buffer = [UInt8].init(repeating: 0, count: 0x40)
        
        for blockStart in stride(from: 0, to: data.count, by: 0x40) {
            let blockEnd = min(blockStart + 0x40, data.count)
            let blockSize = blockEnd - blockStart
            buffer.replaceSubrange(0 ..< blockSize, with: data[blockStart ..< blockEnd])
            try setOutputReport(buffer, id: 0)
            Thread.sleep(forTimeInterval: 0.02)
        }
    }
    
    func requestBulkData(id: UInt8, expectedSize: Int, args: [UInt8], onComplete: @escaping ([UInt8], [UInt8]) -> Void, onError: @escaping (Error) -> Void) {
        let queueEntry = BulkRead.init(
            request: (id, args),
            size: expectedSize,
            onComplete: onComplete,
            onError: onError)
        bulkReadQueue.append(queueEntry)
        if bulkReadQueue.count == 1 {
            dispatchRequestFromQueue()
        }
    }
    
    private func dispatchRequestFromQueue() {
        let op = bulkReadQueue.first!
        let (id, args) = op.request
        do {
            op.reply = try getCommand(id: id, args: args)
        } catch {
            op.onError(error)
        }
    }
    
    override func handleInputReport(_ data: [UInt8], id: Int) {
        if (!bulkReadQueue.isEmpty) {
            let op = bulkReadQueue.first!
            let blockStart = op.nextPosition
            let blockEnd = min(op.nextPosition + 0x40, op.data.count)
            let blockSize = blockEnd - blockStart
            op.data.replaceSubrange(blockStart ..< blockEnd, with: data[0 ..< blockSize])
            op.nextPosition = blockEnd
            
            if op.nextPosition >= op.data.count {
                bulkReadQueue.removeFirst()
                op.onComplete(op.reply, op.data)
                
                if !bulkReadQueue.isEmpty {
                    dispatchRequestFromQueue()
                }
            }
        }
    }
    
    func getFirmwareVersion() throws -> (UInt8, UInt8) {
        let reply = try getCommand(id: 0x80, args: [0, 0, 0, 0, 0, 0])
        return (reply[1], reply[2])
    }
    
    func getFlags() throws -> UInt8 {
        let reply = try getCommand(id: 0x81, args: [0, 0, 0, 0, 0, 0])
        return reply[1]
    }
    
    func setFlags(_ flags: UInt8) throws {
        try setCommand(id: 1, args: [flags, 0, 0, 0, 0, 0])
    }
    
    func getProfile() throws -> UInt8 {
        let reply = try getCommand(id: 0x82, args: [0, 0, 0, 0, 0, 0])
        return reply[1]
    }
    
    func setProfile(_ profileId: UInt8) throws {
        try setCommand(id: 2, args: [profileId, 0, 0, 0, 0, 0])
    }
    
    func getReportRate(profileId: UInt8) throws -> UInt8 {
        let reply = try getCommand(id: 0x83, args: [profileId, 0, 0, 0, 0, 0])
        return reply[2]
    }
    
    func setReportRate(_ reportRate: UInt8, profileId: UInt8) throws {
        try setCommand(id: 3, args: [profileId, reportRate, 0, 0, 0, 0])
    }
    
    func getDpiStage(profileId: UInt8) throws -> UInt8 {
        let reply = try getCommand(id: 0x84, args: [profileId, 0, 0, 0, 0, 0])
        return reply[2]
    }
    
    func setDpiStage(_ dpiStage: UInt8, profileId: UInt8) throws {
        try setCommand(id: 4, args: [profileId, dpiStage, 0, 0, 0, 0])
    }

    func getSideLight() throws -> Bool {
        let reply = try getCommand(id: 0x85, args: [0, 0, 0, 0, 0, 0])
        return (reply[1] & 1) != 0
    }
    
    func setSideLight(on: Bool) throws {
        try setCommand(id: 5, args: [on ? 1 : 0, 0, 0, 0, 0, 0])
    }
    
    func clearReports() throws {
        try setCommand(id: 8, args: [0xAA, 0xCC, 0xEE, 0, 0, 0])
    }
    
    func blinkLights(color: (UInt8, UInt8, UInt8), delay: UInt8, count: UInt8) throws {
        try setCommand(id: 9, args: [color.0, color.1, color.2, delay, count, 0])
    }
    
    func activateBootloader() throws {
        try setCommand(id: 0xA, args: [0xAA, 0x55, 0xCC, 0x33, 0xBB, 0x99])
    }
    
    func checkBootloaderState() throws -> Bool {
        let reply = try getCommand(id: 0x8A, args: [0, 0, 0, 0, 0, 0])
        return reply[1] == 0xFF
    }
    
    func requestConfig(profileId: UInt8, onComplete: @escaping ([UInt8]) -> Void, onError: @escaping (Error) -> Void) throws {
        requestBulkData(
            id: 0x8C, expectedSize: 0x80, args: [profileId, 0, 0, 0, 0, 0],
            onComplete: { reply, data in
                onComplete(data)
            },
            onError: onError)
    }
    
    func writeConfig(_ data: [UInt8], profileId: UInt8) throws {
        if data.count != 0x80 {
            throw TM155Error.sizeError
        }
        
        try writeBulkData(id: 0xC, args: [profileId, 0x80, 0, 0, 0, 0], data: data)
    }
    
    func requestButtonMappings(profileId: UInt8, onComplete: @escaping ([UInt32]) -> Void, onError: @escaping (Error) -> Void) throws {
        requestBulkData(
            id: 0x8D, expectedSize: 0x80, args: [profileId, 0, 0, 0, 0, 0],
            onComplete: { reply, data in
                // Turn this data into a nice array of U32s
                var parsed = [UInt32].init(repeating: 0, count: 32)
                for (index, offset) in stride(from: 0, to: 0x80, by: 4).enumerated() {
                    let a = UInt32(data[offset])
                    let b = UInt32(data[offset + 1])
                    let c = UInt32(data[offset + 2])
                    let d = UInt32(data[offset + 3])
                    parsed[index] = a | (b << 8) | (c << 16) | (d << 24)
                }
                onComplete(parsed)
            },
            onError: onError)
    }
}
