//
//  HIDManager.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 23/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Cocoa
import IOKit.hid

protocol HIDManagerDelegate: AnyObject {
    func deviceConnected(_ device: IOHIDDevice)
    func deviceDisconnected(_ device: IOHIDDevice)
    func device(_ device: IOHIDDevice, received input: [UInt8], id: Int)
}

enum HIDManagerError: Error {
    case ioError(IOReturn)
    case managerAlreadyOpened
}

class HIDManager {
    var base: IOHIDManager
    private var opened = false
    weak var delegate: HIDManagerDelegate?
    
    init() {
        base = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatching(base, nil)
        
        let matchCallback: IOHIDDeviceCallback = { context, ret, sender, device in
            if let context_ = context {
                let hc = Unmanaged<HIDManager>.fromOpaque(context_).takeUnretainedValue()
                hc.delegate?.deviceConnected(device)
            }
        }
        let removalCallback: IOHIDDeviceCallback = { context, ret, sender, device in
            print("MANAGER REMOVAL START")
            if let context_ = context {
                let hc = Unmanaged<HIDManager>.fromOpaque(context_).takeUnretainedValue()
                hc.delegate?.deviceDisconnected(device)
            }
            print("MANAGER REMOVAL END")
        }
        let reportCallback: IOHIDReportCallback = { context, ret, sender, reportType, reportID, report, reportLength in
            if let context_ = context, let sender_ = sender {
                let hc = Unmanaged<HIDManager>.fromOpaque(context_).takeUnretainedValue()
                if let delegate_ = hc.delegate {
                    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender_).takeUnretainedValue()
                    let reportData = UnsafeBufferPointer.init(start: report, count: reportLength)
                    delegate_.device(device, received: [UInt8].init(reportData), id: Int(reportID))
                }
            }
        }

        let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(base, matchCallback, unsafeSelf)
        IOHIDManagerRegisterDeviceRemovalCallback(base, removalCallback, unsafeSelf)
        IOHIDManagerRegisterInputReportCallback(base, reportCallback, unsafeSelf)
    }
    
    deinit {
        let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(base, nil, unsafeSelf)
        IOHIDManagerRegisterDeviceRemovalCallback(base, nil, unsafeSelf)
        IOHIDManagerRegisterInputReportCallback(base, nil, unsafeSelf)

        if opened {
            IOHIDManagerClose(base, 0)
            opened = false
        }
    }
    
    func open() throws {
        if opened {
            throw HIDManagerError.managerAlreadyOpened
        }
        
        IOHIDManagerScheduleWithRunLoop(base, RunLoop.current.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        let ret = IOHIDManagerOpen(base, 0)
        
        if ret == kIOReturnSuccess {
            opened = true
        } else {
            throw HIDManagerError.ioError(ret)
        }
    }
}
