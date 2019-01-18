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

enum TM155KeyModifier: Int {
    case leftControl = 0, leftShift, leftAlt, leftSuper
    case rightControl = 4, rightShift, rightAlt, rightSuper
}

struct TM155KeyModifierFlags: OptionSet {
    let rawValue: UInt8
    
    static let leftControl = TM155KeyModifierFlags(rawValue: 1)
    static let leftShift = TM155KeyModifierFlags(rawValue: 2)
    static let leftAlt = TM155KeyModifierFlags(rawValue: 4)
    static let leftSuper = TM155KeyModifierFlags(rawValue: 8)
    static let rightControl = TM155KeyModifierFlags(rawValue: 0x10)
    static let rightShift = TM155KeyModifierFlags(rawValue: 0x20)
    static let rightAlt = TM155KeyModifierFlags(rawValue: 0x40)
    static let rightSuper = TM155KeyModifierFlags(rawValue: 0x80)
    
    static let allValues: [TM155KeyModifierFlags] = [
        .leftControl, .leftShift, .leftAlt, .leftSuper,
        .rightControl, .rightShift, .rightAlt, .rightSuper
    ]
    
    var description: String {
        var bits: [String] = []
        if self.contains(.leftControl) {
            bits.append("Left ⌃")
        }
        if self.contains(.leftShift) {
            bits.append("Left ⇧")
        }
        if self.contains(.leftAlt) {
            bits.append("Left ⌥")
        }
        if self.contains(.leftSuper) {
            bits.append("Left ⌘")
        }
        if self.contains(.rightControl) {
            bits.append("Right ⌃")
        }
        if self.contains(.rightShift) {
            bits.append("Right ⇧")
        }
        if self.contains(.rightAlt) {
            bits.append("Right ⌥")
        }
        if self.contains(.rightSuper) {
            bits.append("Right ⌘")
        }
        return bits.isEmpty ? "None" : bits.joined(separator: ", ")
    }
}


enum TM155Key: UInt8 {
    // this is gonna be ugly, no two ways about it
    case a = 4, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    
    case _1 = 0x1E, _2, _3, _4, _5, _6, _7, _8, _9, _0
    
    case returnOrEnter = 0x28, escape, backspace, tab, space
    case hyphen, equals, openBracket, closeBracket
    case backslash, nonUSPound, semicolon, quote
    case grave, comma, period, slash, capsLock
    
    case F1 = 0x3A, F2, F3, F4, F5, F6
    case F7, F8, F9, F10, F11, F12
    case printScreen, scrollLock, pause, insert
    case home, pageUp, delete, end, pageDown
    case right, left, down, up
    
    case numLock = 0x53
    case keypadSlash, keypadAsterisk, keypadHyphen, keypadPlus
    case keypadEnter, keypad1, keypad2, keypad3
    case keypad4, keypad5, keypad6, keypad7
    case keypad8, keypad9, keypad0, keypadPeriod
    
    case nonUSBackslash = 0x64, application, power
    case keypadEquals
    
    case F13 = 0x68, F14, F15, F16, F17, F18
    case F19, F20, F21, F22, F23, F24
    case execute, help, menu, select, stop, again
    case undo, cut, copy, paste, find, mute
    case volumeUp, volumeDown
    case lockingCapsLock, lockingNumLock, lockingScrollLock
    
    case keypadComma = 0x85, keypadEqualsAS400
    case international1, international2, international3
    case international4, international5, international6
    case international7, international8, international9
    case lang1, lang2, lang3, lang4, lang5
    case lang6, lang7, lang8, lang9
    
    case altErase, sysRq, cancel, clear, prior
    case return_, separator, out, oper
    case clearOrAgain, crSelOrProps, exSel
    
    case leftControl = 0xE0, leftShift, leftAlt, leftSuper
    case rightControl, rightShift, rightAlt, rightSuper
    
    static var allValues: [TM155Key] {
        let range1 = TM155Key.a.rawValue ... TM155Key.exSel.rawValue
        let range2 = TM155Key.leftControl.rawValue ... TM155Key.rightSuper.rawValue
        let group1 = range1.map({ (x) -> TM155Key in TM155Key.init(rawValue: x)! })
        let group2 = range2.map({ (x) -> TM155Key in TM155Key.init(rawValue: x)! })
        return group1 + group2
    }
    
    var description: String {
        return "Key:\(rawValue)"
    }
}

enum TM155MouseButton: UInt8 {
    case left = 0xF0
    case right
    case middle
    case button4
    case button5
    case tiltLeft
    case tiltRight
    case wheelUp
    case wheelDown
    
    var description: String {
        switch self {
        case .left: return "Left Button"
        case .right: return "Right Button"
        case .middle: return "Middle Button"
        case .button4: return "Button 4"
        case .button5: return "Button 5"
        case .tiltLeft: return "Tilt Left"
        case .tiltRight: return "Tilt Right"
        case .wheelUp: return "Wheel Up"
        case .wheelDown: return "Wheel Down"
        }
    }
}

enum TM155MouseOrKey: Equatable {
    case key(TM155Key)
    case mouse(TM155MouseButton)
    
    init?(rawValue: UInt8) {
        if let k = TM155Key.init(rawValue: rawValue) {
            self = .key(k)
        } else if let m = TM155MouseButton.init(rawValue: rawValue) {
            self = .mouse(m)
        } else {
            return nil
        }
    }
    
    var rawValue: UInt8 {
        switch self {
        case .key(let k):
            return k.rawValue
        case .mouse(let m):
            return m.rawValue
        }
    }
    
    var description: String {
        switch self {
        case .key(let k): return k.description
        case .mouse(let m): return m.description
        }
    }
}

struct TM155SystemControl: OptionSet {
    let rawValue: UInt8
    
    static let powerDown = TM155SystemControl(rawValue: 1)
    static let sleep = TM155SystemControl(rawValue: 2)
    static let wakeUp = TM155SystemControl(rawValue: 4)
    
    var description: String {
        var bits: [String] = []
        if self.contains(.powerDown) {
            bits.append("Power Down")
        }
        if self.contains(.sleep) {
            bits.append("Sleep")
        }
        if self.contains(.wakeUp) {
            bits.append("Wake Up")
        }
        return bits.joined(separator: ", ")
    }
}

enum TM155ConsumerControl: UInt16 {
    // old windows ref: http://download.microsoft.com/download/E/3/A/E3AEC7D7-245D-491F-BB8A-E1E05A03677A/keyboard-support-windows-8.docx
    // handled by hidserv on windows
    // not sure where to look for OS X info just yet
    
    case power               = 0x30
    case sleep               = 0x32
    case menu                = 0x40
    case brightnessUp        = 0x6F  // win-only
    case brightnessDown      = 0x70  // win-only
    case brightnessMin       = 0x73
    case brightnessMax       = 0x74
    case brightnessAuto      = 0x75
    case channelUp           = 0x9C  // win appcmd33
    case channelDown         = 0x9D  // win appcmd34
    case mediaPlay           = 0xB0  // win appcmd2E
    case mediaPause          = 0xB1  // win appcmd2F
    case mediaRecord         = 0xB2  // win appcmd30
    case mediaFastForward    = 0xB3  // win appcmd31
    case mediaRewind         = 0xB4  // win appcmd32
    case mediaNextTrack      = 0xB5  // win
    case mediaPreviousTrack  = 0xB6  // win
    case mediaStop           = 0xB7  // win
    case mediaEject          = 0xB8  // win
    case mediaPlayOrPause    = 0xCD  // win appcmd37

    case mute                = 0xE2  // win appcmd08
    case bassBoost           = 0xE5  // win appcmd14
    case loudness            = 0xE7  // win - old versions only?
    case volumeUp            = 0xE9  // win appcmd0A
    case volumeDown          = 0xEA  // win
    case bassUp              = 0x152 // win appcmd15
    case bassDown            = 0x153 // win appcmd13
    case trebleUp            = 0x154 // win appcmd17
    case trebleDown          = 0x155 // win appcmd16
    
    case consumerControlCfg  = 0x183 // win VK_LAUNCH_MEDIA_SELECT
    case emailReader         = 0x18A // win VK_LAUNCH_MAIL
    case calculator          = 0x192 // win VK_LAUNCH_APP2
    case localBrowser        = 0x194 // win VK_LAUNCH_APP1
    case researchBrowser     = 0x1C6 // win calls weird stuff hids:1
    case search              = 0x221 // win
    case home                = 0x223 // win
    case back                = 0x224 // win
    case forward             = 0x225 // win
    case stop                = 0x226 // win
    case refresh             = 0x227 // win
    // 228, 229 - previous/next link, ignored by hidserv
    case bookmarks           = 0x22A // win
    
    // reserved windows-specific stuff
    // none of these appcmds are documented but they do seem to be
    // fired by hidserv...
    case unkD1               = 0xD1  // win appcmd38
    case unkD2               = 0xD2  // win appcmd39
    case unkD3               = 0xD3  // win appcmd3A
    case unkD4               = 0xD4  // win appcmd3B
    case unkD5               = 0xD5  // win appcmd3C
    case unkD6               = 0xD6  // win appcmd3D
    case unkD7               = 0xD7  // win appcmd3E
    case unk2C7              = 0x2C7 // win unk0
    case unk2C8              = 0x2C8 // win unk1
    case unk1C8              = 0x1C8 // win unk2 - navigation?
    
    var description: String {
        return String(describing: self)
    }
}

enum TM155ScrollEvent: UInt8 {
    case wheelUp = 1
    case wheelDown = 2
    case tiltRight = 3
    case tiltLeft = 4
    
    var description: String {
        switch self {
        case .tiltLeft: return "Tilt Left"
        case .tiltRight: return "Tilt Right"
        case .wheelUp: return "Wheel Up"
        case .wheelDown: return "Wheel Down"
        }
    }
}

enum TM155MacroRepeatMode: UInt8 {
    case specifiedLoops = 0
    case untilKeyPressed = 1
    case untilKeyReleased = 2
}

enum TM155Button: Equatable {
    // Type 00: Keyboard Event
    case key(TM155KeyModifierFlags, TM155Key?, TM155Key?)
    
    // Type 01: Mouse Event
    case mouse(TM155MouseButton)
    
    // Type 02: System Control (flags!)
    case systemControl(TM155SystemControl)
    
    // Type 03: Consumer Control 0-2FF
    case consumerControl(TM155ConsumerControl)
    
    // Type 04: Single Scroll
    case scroll(TM155ScrollEvent)
    
    // Type 05: Report Rate <1..3>
    case reportRateUp
    case reportRateDown
    case reportRateCycle
    
    // Type 06: Notify App via Report 6
    case notifyApp(UInt8, UInt8, UInt8)
    
    // Type 07: DPI Stage <1..3>
    case dpiStageUp
    case dpiStageDown
    case dpiStageCycle
    
    // Type 08: Profile Adjustment <0..3, FF>
    case profilePrevious
    case profileUp
    case profileDown
    case profileCycle
    case profileUnkFF
    
    // Type 09: Macro
    case macro(id: UInt8, TM155MacroRepeatMode)
    
    // Type 0A: Timed Repeat
    case timedRepeat(TM155MouseOrKey, delay: UInt8, count: UInt8)
    
    // What if xx is 00, 01? To be discovered
    case bt0A0(UInt8, UInt8)
    case bt0A1(UInt8, UInt8)

    // Type 0B: Chord Events <0..6>
    case overrideDpi(x: UInt8, y: UInt8)
    case overrideSensitivity(x: UInt8, y: UInt8)
    case keyAndTab(TM155Key, delay: UInt8)
    case alternateButtonGroup
    case adjustDPI(UInt8, UInt8)
    case adjustSensitivity(UInt8, UInt8)
    case cycleColour(max: UInt8)

    // Flag 0x80: Odd little countdown thing
    case lastBit(TM155KeyModifierFlags, TM155MouseOrKey?, TM155MouseOrKey?, delay: UInt8)
    
    
    static func fromBytes(bytes: Slice<[UInt8]>) -> TM155Button? {
        assert(bytes.count == 4)
        let a = bytes[bytes.startIndex]
        let b = bytes[bytes.startIndex + 1]
        let c = bytes[bytes.startIndex + 2]
        let d = bytes[bytes.startIndex + 3]
        
        if (a & 0x80) != 0 {
            let delay = a & 0x7F
            let mk1 = (b > 0) ? TM155MouseOrKey.init(rawValue: b) : nil
            let mk2 = (c > 0) ? TM155MouseOrKey.init(rawValue: c) : nil
            let modifier = TM155KeyModifierFlags.init(rawValue: d)
            return self.lastBit(modifier, mk1, mk2, delay: delay)
        }
        
        switch a {
        case 0:
            let modifier = TM155KeyModifierFlags.init(rawValue: b)
            let key1 = (c > 0) ? TM155Key.init(rawValue: c) : nil
            let key2 = (d > 0) ? TM155Key.init(rawValue: d) : nil
            return self.key(modifier, key1, key2)
        case 1:
            if let button = TM155MouseButton.init(rawValue: c) {
                return self.mouse(button)
            }
        case 2:
            let control = TM155SystemControl.init(rawValue: c)
            return self.systemControl(control)
        case 3:
            if let control = TM155ConsumerControl.init(rawValue: UInt16(c) | (UInt16(d) << 8)) {
                return self.consumerControl(control)
            }
        case 4:
            if let event = TM155ScrollEvent(rawValue: c) {
                return self.scroll(event)
            }
        case 5:
            switch c {
            case 1: return self.reportRateUp
            case 2: return self.reportRateDown
            case 3: return self.reportRateCycle
            default: break
            }
        case 6:
            return self.notifyApp(b, c, d)
        case 7:
            switch c {
            case 1: return self.dpiStageUp
            case 2: return self.dpiStageDown
            case 3: return self.dpiStageCycle
            default: break
            }
        case 8:
            switch c {
            case 0: return self.profilePrevious
            case 1: return self.profileUp
            case 2: return self.profileDown
            case 3: return self.profileCycle
            case 0xFF: return self.profileUnkFF
            default: break
            }
        case 9:
            if let repeatMode = TM155MacroRepeatMode.init(rawValue: b) {
                return self.macro(id: c, repeatMode)
            }
        case 0xA:
            if b == 0 {
                return self.bt0A0(c, d)
            } else if b == 1 {
                return self.bt0A1(c, d)
            } else if let mouseOrKey = TM155MouseOrKey.init(rawValue: b) {
                return self.timedRepeat(mouseOrKey, delay: c, count: d)
            }
        case 0xB:
            switch b {
            case 0: return self.overrideDpi(x: c, y: d)
            case 1: return self.overrideSensitivity(x: c, y: d)
            case 2:
                if let key = TM155Key.init(rawValue: c) {
                    return self.keyAndTab(key, delay: d)
                }
            case 3: return self.alternateButtonGroup
            case 4: return self.adjustDPI(c, d)
            case 5: return self.adjustSensitivity(c, d)
            case 6: return self.cycleColour(max: c)
            default: break
            }
        default: break
        }
        
        return nil
    }
    
    var bytes: [UInt8] {
        switch self {
        case .key(let modifier, let key1, let key2):
            return [0, modifier.rawValue, key1?.rawValue ?? 0, key2?.rawValue ?? 0]
        case .mouse(let button):
            return [1, 0, button.rawValue, 0]
        case .systemControl(let control):
            return [2, 0, control.rawValue, 0]
        case .consumerControl(let control):
            return [3, 0, UInt8(control.rawValue & 0xFF), UInt8(control.rawValue >> 8)]
        case .scroll(let event):
            return [4, 0, event.rawValue, 0]
        case .reportRateUp:
            return [5, 0, 1, 0]
        case .reportRateDown:
            return [5, 0, 2, 0]
        case .reportRateCycle:
            return [5, 0, 3, 0]
        case .notifyApp(let a, let b, let c):
            return [6, a, b, c]
        case .dpiStageUp:
            return [7, 0, 1, 0]
        case .dpiStageDown:
            return [7, 0, 2, 0]
        case .dpiStageCycle:
            return [7, 0, 3, 0]
        case .profilePrevious:
            return [8, 0, 0, 0]
        case .profileUp:
            return [8, 0, 1, 0]
        case .profileDown:
            return [8, 0, 2, 0]
        case .profileCycle:
            return [8, 0, 3, 0]
        case .profileUnkFF:
            return [8, 0, 0xFF, 0]
        case .macro(id: let id, let repeatMode):
            return [9, repeatMode.rawValue, id, 0]
        case .timedRepeat(let mouseOrKey, delay: let delay, count: let count):
            return [0xA, mouseOrKey.rawValue, delay, count]
        case .bt0A0(let a, let b):
            return [0xA, 0, a, b]
        case .bt0A1(let a, let b):
            return [0xA, 1, a, b]
        case .overrideDpi(x: let x, y: let y):
            return [0xB, 0, x, y]
        case .overrideSensitivity(x: let x, y: let y):
            return [0xB, 1, x, y]
        case .keyAndTab(let key, delay: let delay):
            return [0xB, 2, key.rawValue, delay]
        case .alternateButtonGroup:
            return [0xB, 3, 0, 0]
        case .adjustDPI(let a, let b):
            return [0xB, 4, a, b]
        case .adjustSensitivity(let a, let b):
            return [0xB, 5, a, b]
        case .cycleColour(max: let max):
            return [0xB, 6, max, 0]
        case .lastBit(let modifier, let mk1, let mk2, delay: let delay):
            return [0x80 | delay, mk1?.rawValue ?? 0, mk2?.rawValue ?? 0, modifier.rawValue]
        }
    }
    
    var description: String {
        switch self {
        case .key(let modifier, let key1, let key2):
            var bits: [String] = []
            if modifier.rawValue != 0 {
                bits.append(modifier.description)
            }
            if let key1 = key1 {
                bits.append(key1.description)
            }
            if let key2 = key2 {
                bits.append(key2.description)
            }
            return bits.joined(separator: " + ")
        case .mouse(let button):
            return button.description
        case .systemControl(let control):
            return control.description
        case .consumerControl(let control):
            return "Consumer Control: \(control.description)"
        case .scroll(let event):
            return "Single Scroll: \(event.description)"
        case .reportRateUp:
            return "Report Rate: Up"
        case .reportRateDown:
            return "Report Rate: Down"
        case .reportRateCycle:
            return "Report Rate: Cycle"
        case .notifyApp(let a, let b, let c):
            return "Notify App: \(a),\(b),\(c)"
        case .dpiStageUp:
            return "DPI: Up"
        case .dpiStageDown:
            return "DPI: Down"
        case .dpiStageCycle:
            return "DPI: Cycle"
        case .profilePrevious:
            return "Profile: Switch to Previous"
        case .profileUp:
            return "Profile: Up"
        case .profileDown:
            return "Profile: Down"
        case .profileCycle:
            return "Profile: Cycle"
        case .profileUnkFF:
            return "Profile: ???"
        case .macro(id: let id, _):
            return "Macro \(id)"
        case .timedRepeat(let mouseOrKey, delay: _, count: let count):
            return "\(count)x \(mouseOrKey.description)"
        case .bt0A0(let a, let b):
            return "0A0 \(a),\(b)"
        case .bt0A1(let a, let b):
            return "0A1 \(a),\(b)"
        case .overrideDpi(x: let x, y: let y):
            return "DPI Override: (\(Int(x) * 200),\(Int(y) * 200))"
        case .overrideSensitivity(x: let x, y: let y):
            return "Sensitivity Override: (\(x),\(y))"
        case .keyAndTab(let key, delay: _):
            return "\(key.description) + Tab"
        case .alternateButtonGroup:
            return "Alternate Button Set"
        case .adjustDPI(let a, let b):
            return "Adjust DPI \(a),\(b)"
        case .adjustSensitivity(let a, let b):
            return "Adjust Sensitivity \(a),\(b)"
        case .cycleColour(max: let max):
            return "Cycle Colours up to \(max)"
        case .lastBit(let modifier, let mk1, let mk2, delay: let delay):
            var bits: [String] = []
            if modifier.rawValue != 0 {
                bits.append(modifier.description)
            }
            if let mk1 = mk1 {
                bits.append(mk1.description)
            }
            if let mk2 = mk2 {
                bits.append(mk2.description)
            }
            return "0x80 Delay \(delay): " + bits.joined(separator: " + ")
        }
    }
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
                if !bulkReadQueue.isEmpty {
                    dispatchRequestFromQueue()
                }
                
                op.onComplete(op.reply, op.data)
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
    
    func requestButtonMappings(profileId: UInt8, onComplete: @escaping ([TM155Button?]) -> Void, onError: @escaping (Error) -> Void) throws {
        requestBulkData(
            id: 0x8D, expectedSize: 0x80, args: [profileId, 0, 0, 0, 0, 0],
            onComplete: { reply, data in
                // Turn this data into a nice array of buttons
                var parsed = [TM155Button?].init(repeating: nil, count: 32)
                for (index, offset) in stride(from: 0, to: 0x80, by: 4).enumerated() {
                    let bytes: Slice<[UInt8]> = data[offset ..< offset+4]
                    let button = TM155Button.fromBytes(bytes: bytes)
                    parsed[index] = button
                }
                onComplete(parsed)
            },
            onError: onError)
    }
    
    func writeButtonMappings(_ buttons: [TM155Button?], profileId: UInt8) throws {
        if buttons.count != 32 {
            throw TM155Error.sizeError
        }
        
        var data = [UInt8](repeating: 0, count: 0x80)
        for (button, offset) in zip(buttons, stride(from: 0, to: 0x80, by: 4)) {
            let bytes = button?.bytes ?? [0, 0, 0, 0]
            data.replaceSubrange(offset ..< offset+4, with: bytes)
        }
        
        try writeBulkData(id: 0xD, args: [profileId, 0x80, 0, 0, 0, 0], data: data)
    }
}
