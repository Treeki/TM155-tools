//
//  HIDDevice.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 23/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import IOKit.hid
import Foundation

enum HIDDeviceError: Error {
    case ioError(IOReturn)
    case deviceAlreadyOpened
}

class HIDDevice {
    let base: IOHIDDevice
    private var registeredCallbacks = false
    private var inputReportBufferPointer: UnsafeMutablePointer<UInt8>? = nil
    private var inputReportBufferSize: Int = 0
    private var featureReportBuffer: [UInt8] = []

    init(_ dev: IOHIDDevice) {
        base = dev
        featureReportBuffer = [UInt8].init(repeating: 0, count: maxFeatureReportSize ?? 1024)
    }
    
    deinit {
        unregisterCallbacks()
    }
    
    func registerCallbacks() {
        if !registeredCallbacks {
            inputReportBufferSize = maxInputReportSize ?? 1024
            inputReportBufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: inputReportBufferSize)
            
            let removalCallback: IOHIDCallback = { context, ret, sender in
                print("REMOVAL CONTEXT:", context?.debugDescription, "SENDER:", sender?.debugDescription, "RET:", ret)
                if let context_ = context {
                    // This will release the device
                    let hd = Unmanaged<HIDDevice>.fromOpaque(context_).takeRetainedValue()
                    hd.handleDisconnected()
                }
            }
            
            let reportCallback: IOHIDReportCallback = { context, ret, sender, reportType, reportID, report, reportLength in
                //print("REPORT CONTEXT:", context?.debugDescription, "SENDER:", sender?.debugDescription, "RET:", ret)
                if let context_ = context {
                    let hd = Unmanaged<HIDDevice>.fromOpaque(context_).takeUnretainedValue()
                    let reportData = UnsafeBufferPointer.init(start: report, count: reportLength)
                    hd.handleInputReport([UInt8].init(reportData), id: Int(reportID))
                }
            }
            
            // This gets released inside the removal callback
            let unsafeSelf = Unmanaged.passRetained(self).toOpaque()
            //print("ATTACHING:", unsafeSelf)
            
            IOHIDDeviceRegisterRemovalCallback(base, removalCallback, unsafeSelf)
            IOHIDDeviceRegisterInputReportCallback(base, inputReportBufferPointer!, inputReportBufferSize, reportCallback, unsafeSelf)
            
            registeredCallbacks = true
        }
    }
    
    func unregisterCallbacks() {
        if registeredCallbacks {
            registeredCallbacks = false
            
            let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()
            //print("DETACHING:", unsafeSelf)
            
            IOHIDDeviceRegisterRemovalCallback(base, nil, unsafeSelf)
            IOHIDDeviceRegisterInputReportCallback(base, inputReportBufferPointer!, 0, nil, unsafeSelf)
                
            inputReportBufferPointer!.deallocate()
        }
    }
    
    var transport: String? {
        return IOHIDDeviceGetProperty(base, kIOHIDTransportKey as CFString) as? String
    }
    var vendorId: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDVendorIDKey as CFString) as? Int
    }
    var vendorIdSource: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDVendorIDSourceKey as CFString) as? Int
    }
    var productId: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDProductIDKey as CFString) as? Int
    }
    var versionNumber: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDVersionNumberKey as CFString) as? Int
    }
    var manufacturer: String? {
        return IOHIDDeviceGetProperty(base, kIOHIDManufacturerKey as CFString) as? String
    }
    var product: String? {
        return IOHIDDeviceGetProperty(base, kIOHIDProductKey as CFString) as? String
    }
    var serialNumber: String? {
        return IOHIDDeviceGetProperty(base, kIOHIDSerialNumberKey as CFString) as? String
    }
    var countryCode: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDCountryCodeKey as CFString) as? Int
    }
    var locationId: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDLocationIDKey as CFString) as? Int
    }
    var deviceUsage: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDDeviceUsageKey as CFString) as? Int
    }
    var deviceUsagePage: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDDeviceUsagePageKey as CFString) as? Int
    }
    var primaryUsage: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDPrimaryUsageKey as CFString) as? Int
    }
    var primaryUsagePage: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDPrimaryUsagePageKey as CFString) as? Int
    }
    var maxInputReportSize: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDMaxInputReportSizeKey as CFString) as? Int
    }
    var maxOutputReportSize: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDMaxOutputReportSizeKey as CFString) as? Int
    }
    var maxFeatureReportSize: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int
    }
    var reportInterval: Int? {
        return IOHIDDeviceGetProperty(base, kIOHIDReportIntervalKey as CFString) as? Int
    }
    var reportDescriptor: Data? {
        return IOHIDDeviceGetProperty(base, kIOHIDReportDescriptorKey as CFString) as? Data
    }
    
    var deviceUsagePairs: [(Int, Int)] {
        let anyPairs = IOHIDDeviceGetProperty(base, kIOHIDDeviceUsagePairsKey as CFString)
        if let dictPairs = (anyPairs as? [Dictionary<String, AnyObject>]) {
            return dictPairs.map({
                let usage = $0[kIOHIDDeviceUsageKey] as? Int
                let usagePage = $0[kIOHIDDeviceUsagePageKey] as? Int
                if let usage_ = usage, let usagePage_ = usagePage {
                    return (usage_, usagePage_)
                } else {
                    return (-1, -1)
                }
            }).filter({ $0 != (-1, -1) })
        } else {
            if let usage = deviceUsage, let usagePage = deviceUsagePage {
                return [(usage, usagePage)]
            } else {
                return []
            }
        }
    }
    
    func implementsUsage(_ usage: Int, page: Int) -> Bool {
        return deviceUsagePairs.contains(where: {$0 == (usage, page)})
    }
    
    func setOutputReport(_ data: [UInt8], id: Int) throws {
        debugPrint("Output-->", id, data)
        
        let ret = data.withUnsafeBufferPointer({ ptr in
            IOHIDDeviceSetReport(base, kIOHIDReportTypeOutput, id, ptr.baseAddress!, ptr.count)
        })
        
        if ret != KERN_SUCCESS {
            throw HIDDeviceError.ioError(ret)
        }
    }
    
    func setFeatureReport(_ data: [UInt8], id: Int) throws {
        debugPrint("Feature->", id, data)
        
        let ret = data.withUnsafeBufferPointer({ ptr in
            IOHIDDeviceSetReport(base, kIOHIDReportTypeFeature, id, ptr.baseAddress!, ptr.count)
        })
        
        if ret != KERN_SUCCESS {
            throw HIDDeviceError.ioError(ret)
        }
    }

    func getFeatureReport(id: Int) throws -> [UInt8] {
        var count: CFIndex = featureReportBuffer.count
        let ret = featureReportBuffer.withUnsafeMutableBufferPointer({ ptr in
            return IOHIDDeviceGetReport(base, kIOHIDReportTypeFeature, id, ptr.baseAddress!, &count)
        })
        
        if ret == KERN_SUCCESS {
            let data = [UInt8].init(featureReportBuffer[0 ..< Int(count)])
            debugPrint("<-Feature", id, data)
            return data
        } else {
            throw HIDDeviceError.ioError(ret)
        }
    }
    
    
    
    open func handleInputReport(_ data: [UInt8], id: Int) {
    }
    
    open func handleDisconnected() {
    }
}
