//
//  AppDelegate.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 23/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Cocoa

extension NSColor {
    convenience init(fromRGB bytes: Slice<[UInt8]>) {
        let rR = bytes[bytes.startIndex]
        let rG = bytes[bytes.startIndex + 1]
        let rB = bytes[bytes.startIndex + 2]
        let r = CGFloat(rR) / CGFloat(255)
        let g = CGFloat(rG) / CGFloat(255)
        let b = CGFloat(rB) / CGFloat(255)
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
    
    func toRGBBytes() -> [UInt8] {
        let r = UInt8(round(redComponent * 255))
        let g = UInt8(round(greenComponent * 255))
        let b = UInt8(round(blueComponent * 255))
        return [r, g, b]
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, HIDManagerDelegate, ProfileWindowDelegate, NSTableViewDelegate, NSTableViewDataSource {
    func deviceConnected(_ device: IOHIDDevice) {
        let device = HIDDevice(device)
        if device.vendorId == 0x4D9 && device.productId == 0xA118 {
            if device.implementsUsage(0xFF00, page: 0xFF00) {
                linkControlDevice(device.base)
            }
            if device.implementsUsage(0x0001, page: 0xFF01) {
                linkNotifyDevice(device.base)
            }
        }
    }
    
    func deviceDisconnected(_ device: IOHIDDevice) {
        if controlDevice?.base == device {
            unlinkControlDevice()
        }
        if notifyDevice?.base == device {
            unlinkNotifyDevice()
        }
    }
    
    func device(_ device: IOHIDDevice, received input: [UInt8], id: Int) {
        if notifyDevice?.base == device {
            print("Received notification from mouse:", id, input)
            
            if input[1] == 7 {
                dpiStageControl.selectItem(withTag: Int(input[3]))
            }
        }
        if controlDevice?.base == device {
        }
    }
    

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var firmwareVersionLabel: NSTextField!
    @IBOutlet weak var sideLightControl: NSButton!
    @IBOutlet weak var activeProfileControl: NSPopUpButton!
    @IBOutlet weak var dpiStageControl: NSPopUpButton!
    @IBOutlet weak var reportRateControl: NSPopUpButton!
    var manager: HIDManager
    var controlDevice: TM155ControlDevice?
    var notifyDevice: HIDDevice?
    var config: [UInt8]

    override init() {
        manager = HIDManager.init()
        config = []
        super.init()
        manager.delegate = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateStatus()
        do {
            try manager.open()
        } catch {
            print("Could not open manager:", error)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func linkControlDevice(_ device: IOHIDDevice) {
        if controlDevice != nil {
            unlinkControlDevice()
        }
        
        controlDevice = TM155ControlDevice(device)
        controlDevice!.registerCallbacks()
        do {
            updateStatus()
            try controlDevice!.setFlags(0xFC)
            try readAllStateFromMouse()
        } catch {
            print("ERROR:", error)
            unlinkControlDevice()
            updateStatus()
        }
    }
    
    func linkNotifyDevice(_ device: IOHIDDevice) {
        if notifyDevice != nil {
            unlinkNotifyDevice()
        }
        
        notifyDevice = HIDDevice(device)
        updateStatus()
    }
    
    func unlinkControlDevice() {
        controlDevice = nil
        updateStatus()
    }
    
    func unlinkNotifyDevice() {
        notifyDevice = nil
        updateStatus()
    }

    
    func updateStatus() {
        let connected = (controlDevice != nil) && (notifyDevice != nil)
        statusLabel.stringValue = connected ? "Connected" : "Disconnected";
        
        activeProfileControl.isEnabled = connected
        dpiStageControl.isEnabled = connected
        reportRateControl.isEnabled = connected
        sideLightControl.isEnabled = connected
        applySettingChangesButton.isEnabled = connected
        dumpLoadButton.isEnabled = connected
        dumpSaveButton.isEnabled = connected
    }
    
    func parseConfig(_ config: [UInt8]) {
        // Try and make some sense out of the global config
        rgbCycle0.color = NSColor.init(fromRGB: config[0x18 ..< 0x1B])
        rgbCycle1.color = NSColor.init(fromRGB: config[0x1B ..< 0x1E])
        rgbCycle2.color = NSColor.init(fromRGB: config[0x1E ..< 0x21])
        rgbCycle3.color = NSColor.init(fromRGB: config[0x21 ..< 0x24])
        rgbCycle4.color = NSColor.init(fromRGB: config[0x24 ..< 0x27])
        
        loadDpiIndicatorLight(bitfield: config[0x10], control: dpiLeds0)
        loadDpiIndicatorLight(bitfield: config[0x11], control: dpiLeds1)
        loadDpiIndicatorLight(bitfield: config[0x12], control: dpiLeds2)
        loadDpiIndicatorLight(bitfield: config[0x13], control: dpiLeds3)
        loadDpiIndicatorLight(bitfield: config[0x14], control: dpiLeds4)
        loadDpiIndicatorLight(bitfield: config[0x15], control: dpiLeds5)
        loadDpiIndicatorLight(bitfield: config[0x16], control: dpiLeds6)
        loadDpiIndicatorLight(bitfield: config[0x17], control: dpiLeds7)
        
        for i in 0 ..< 6 {
            let flag = UInt8(1) << i
            enabledProfiles[i] = (config[2] & flag) != 0
        }
        enabledProfileList.reloadData()
    }
    
    func readAllStateFromMouse() throws {
        let sideLight = try controlDevice!.getSideLight()
        sideLightControl.state = sideLight ? NSControl.StateValue.on : NSControl.StateValue.off;
        
        let profileId = try controlDevice!.getProfile()
        activeProfileControl.selectItem(withTag: Int(profileId))
        
        try reloadProfileInfo()
        
        let fwVer = try controlDevice!.getFirmwareVersion()
        firmwareVersionLabel.stringValue = "\(fwVer.0).\(fwVer.1)";
        
        try controlDevice!.requestConfig(profileId: profileId, onComplete: { config in
            self.parseConfig(config)
        }, onError: { error in
            print("Failed to get config:", error)
        })
    }
    
    func reloadProfileInfo() throws {
        let profileId = UInt8(activeProfileControl.selectedTag())

        let dpiStage = try controlDevice!.getDpiStage(profileId: profileId)
        let reportRate = try controlDevice!.getReportRate(profileId: profileId)
        
        dpiStageControl.selectItem(withTag: Int(dpiStage))
        reportRateControl.selectItem(withTag: Int(reportRate))
    }

    @IBAction func selectActiveProfile(_ sender: Any) {
        let profileId = UInt8(activeProfileControl.selectedTag())
        try! controlDevice!.setProfile(profileId)
        try! reloadProfileInfo()
    }
    
    @IBAction func selectDpiStage(_ sender: Any) {
        let profileId = UInt8(activeProfileControl.selectedTag())
        let dpiStage = UInt8(dpiStageControl.selectedTag())
        try! controlDevice!.setDpiStage(dpiStage, profileId: profileId)
    }
    
    @IBAction func selectReportRate(_ sender: Any) {
        let profileId = UInt8(activeProfileControl.selectedTag())
        let reportRate = UInt8(reportRateControl.selectedTag())
        try! controlDevice!.setReportRate(reportRate, profileId: profileId)
    }
    
    @IBAction func sideLightControl(_ sender: Any) {
        let value = sideLightControl.state == NSControl.StateValue.on
        try! controlDevice!.setSideLight(on: value)
    }
    
    
    
    // Settings Tab
    private var enabledProfiles: [Bool] = [true, false, false, false, false, false]
    
    @IBOutlet weak var enabledProfileList: NSTableView!
    @IBOutlet weak var dpiLeds0: NSSegmentedControl!
    @IBOutlet weak var dpiLeds1: NSSegmentedControl!
    @IBOutlet weak var dpiLeds2: NSSegmentedControl!
    @IBOutlet weak var dpiLeds3: NSSegmentedControl!
    @IBOutlet weak var dpiLeds4: NSSegmentedControl!
    @IBOutlet weak var dpiLeds5: NSSegmentedControl!
    @IBOutlet weak var dpiLeds6: NSSegmentedControl!
    @IBOutlet weak var dpiLeds7: NSSegmentedControl!
    @IBOutlet weak var rgbCycle0: NSColorWell!
    @IBOutlet weak var rgbCycle1: NSColorWell!
    @IBOutlet weak var rgbCycle2: NSColorWell!
    @IBOutlet weak var rgbCycle3: NSColorWell!
    @IBOutlet weak var rgbCycle4: NSColorWell!
    @IBOutlet weak var editProfileButton: NSButton!
    @IBOutlet weak var applySettingChangesButton: NSButton!

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == enabledProfileList {
            return 6
        }
        return -1
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == enabledProfileList {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ProfileCell"), owner: self) as! ButtonTableCellView
            let on = enabledProfiles[row]
            view.button.state = on ?NSControl.StateValue.on : NSControl.StateValue.off
            view.textField?.stringValue = "Profile \(row+1)"
            return view
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if tableView == enabledProfileList {
            editProfileButton.isEnabled = (enabledProfileList.selectedRow >= 0)
        }
    }
    
    func loadDpiIndicatorLight(bitfield: UInt8, control: NSSegmentedControl) {
        for i in 0 ..< 4 {
            let flag = UInt8(1) << i
            let status = (bitfield & flag) != 0
            control.setSelected(status, forSegment: i)
        }
    }
    
    func saveDpiIndicatorLight(control: NSSegmentedControl) -> UInt8 {
        var result = UInt8(0)
        for i in 0 ..< 4 {
            if control.isSelected(forSegment: i) {
                result |= UInt8(1) << i
            }
        }
        return result
    }
    
    
    private var profileWindows: [ProfileWindow?] = [nil, nil, nil, nil, nil, nil]
    
    @IBAction func editProfile(_ sender: Any) {
        let id = enabledProfileList.selectedRow
        if id >= 0 {
            if case .none = self.profileWindows[id] {
                self.profileWindows[id] = ProfileWindow.init(windowNibName: "ProfileWindow")
                self.profileWindows[id]?.delegate = self
            }
            
            let window = self.profileWindows[id]!
            if window.window!.isVisible {
                print("Showing again")
                window.window!.makeKeyAndOrderFront(self)
            } else {
                print("Setup from closed")
                // request everything we need
                if let dev = controlDevice {
                    try! dev.requestConfig(profileId: UInt8(id), onComplete: { config in
                        try! dev.requestButtonMappings(profileId: UInt8(id), onComplete: { buttons in
                            // we've got everything we need, build the window
                            window.setup(profileId: id, config: config, buttons: buttons)
                            window.showWindow(self)
                        }, onError: { error in
                            NSAlert.init(error: error).runModal()
                        })
                    }, onError: { error in
                        NSAlert.init(error: error).runModal()
                    })
                }
            }
        }
    }
    
    func profileSaved(id: Int, config: [UInt8], buttons: [TM155Button?]) {
        try! controlDevice?.writeConfig(config, profileId: UInt8(id))
        try! controlDevice?.writeButtonMappings(buttons, profileId: UInt8(id))
    }
    
    
    @IBAction func applySettingChanges(_ sender: Any) {
        // Fetch the current global config, first
        try! controlDevice!.requestConfig(profileId: 0, onComplete: { config in
            var newConfig = config
            
            // Apply the profile flags
            var profileFlag = UInt8(0)
            for (i, value) in self.enabledProfiles.enumerated() {
                if value {
                    profileFlag |= UInt8(1) << i
                }
            }
            newConfig[2] = profileFlag
            
            // Generate the DPI fields
            newConfig[0x10] = self.saveDpiIndicatorLight(control: self.dpiLeds0)
            newConfig[0x11] = self.saveDpiIndicatorLight(control: self.dpiLeds1)
            newConfig[0x12] = self.saveDpiIndicatorLight(control: self.dpiLeds2)
            newConfig[0x13] = self.saveDpiIndicatorLight(control: self.dpiLeds3)
            newConfig[0x14] = self.saveDpiIndicatorLight(control: self.dpiLeds4)
            newConfig[0x15] = self.saveDpiIndicatorLight(control: self.dpiLeds5)
            newConfig[0x16] = self.saveDpiIndicatorLight(control: self.dpiLeds6)
            newConfig[0x17] = self.saveDpiIndicatorLight(control: self.dpiLeds7)
            
            // Generate the RGB colours
            newConfig.replaceSubrange(0x18 ..< 0x1B, with: self.rgbCycle0.color.toRGBBytes())
            newConfig.replaceSubrange(0x1B ..< 0x1E, with: self.rgbCycle1.color.toRGBBytes())
            newConfig.replaceSubrange(0x1E ..< 0x21, with: self.rgbCycle2.color.toRGBBytes())
            newConfig.replaceSubrange(0x21 ..< 0x24, with: self.rgbCycle3.color.toRGBBytes())
            newConfig.replaceSubrange(0x24 ..< 0x27, with: self.rgbCycle4.color.toRGBBytes())
            
            // Finally, write it over
            do {
                try self.controlDevice?.writeConfig(newConfig, profileId: 0)
            } catch {
                NSAlert.init(error: error).runModal()
            }

        }, onError: { error in
            print("Error requesting config", error)
        })
    }
    
    
    // Dump
    @IBOutlet weak var dumpProfileControl: NSPopUpButton!
    @IBOutlet weak var dumpControl: HFTextField!
    @IBOutlet weak var dumpLoadButton: NSButton!
    @IBOutlet weak var dumpSaveButton: NSButton!
    
    @IBAction func dumpLoad(_ sender: Any) {
        let what = dumpProfileControl.selectedTag()
        let cmd = UInt8([0x8C, 0x8D, 0x8F][(what - 100) / 100])
        let id = what % 100
        let args = [UInt8(id), 0, 0, 0, 0, 0]

        controlDevice!.requestBulkData(id: cmd, expectedSize: 0x80, args: args, onComplete: { (_, configBlock) in
            let data = NSMutableData.init(data: Data.init(configBlock))
            let slice = HFSharedMemoryByteSlice.init(data: data)
            let array = HFBTreeByteArray.init(byteSlice: slice)
            self.dumpControl.objectValue = array
        }, onError: { error in
            print("Couldn't load:", error)
        })
    }
    
    @IBAction func dumpSave(_ sender: Any) {
        let what = dumpProfileControl.selectedTag()
        let cmd = UInt8([0xC, 0xD, 0xF][(what - 100) / 100])
        let id = what % 100
        let args = [UInt8(id), 0x80, 0, 0, 0, 0]
        
        let hfArray: HFByteArray = self.dumpControl.objectValue! as! HFByteArray
        var array = [UInt8].init(repeating: 0, count: Int(hfArray.length()))
        array.withUnsafeMutableBufferPointer({ ptr in
            hfArray.copyBytes(ptr.baseAddress!, range: HFRange.init(location: 0, length: hfArray.length()))
        })

        try! controlDevice!.writeBulkData(id: cmd, args: args, data: array)
    }
}

