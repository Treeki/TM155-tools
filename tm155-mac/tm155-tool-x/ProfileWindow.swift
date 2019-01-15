//
//  ProfileWindow.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 25/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Cocoa

protocol ProfileWindowDelegate: AnyObject {
    func profileSaved(id: Int, config: [UInt8], buttons: [TM155Button?])
}

class ProfileWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, ButtonActionDelegate {
    public weak var delegate: ProfileWindowDelegate?
    
    private var profileId: Int = -1
    private var config: [UInt8] = []
    private var buttons: [TM155Button?] = []
    private let altButtonOffset = 16
    private var editedButtonIndex: Int = -1
    
    static let ButtonDefinitions: [(Int, String)] = [
        (0, "Left"),
        (1, "Right"),
        (2, "Middle"),
        (14, "Wheel Up"),
        (15, "Wheel Down"),
        (5, "Wheel Left"),
        (6, "Wheel Right"),
        (3, "DPI+"),
        (4, "DPI-"),
        (11, "M1"),
        (10, "M2"),
        (9, "M3"),
        (8, "M4"),
        (7, "M5"),
    ]
    

    @IBOutlet var popover: NSPopover!
    @IBOutlet weak var buttonTable: NSTableView!
    @IBOutlet weak var buttonColumn: NSTableColumn!
    @IBOutlet weak var mainActionColumn: NSTableColumn!
    @IBOutlet weak var altActionColumn: NSTableColumn!
    @IBOutlet weak var enable1000Hz: NSButton!
    @IBOutlet weak var enable500Hz: NSButton!
    @IBOutlet weak var enable250Hz: NSButton!
    @IBOutlet weak var enable125Hz: NSButton!
    @IBOutlet weak var buttonActionEditor: ButtonActionController!

    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func setup(profileId: Int, config: [UInt8], buttons: [TM155Button?]) {
        self.profileId = profileId
        self.config = config
        self.buttons = buttons
        
        let disabledRates = config[0x40]
        enable1000Hz.state = ((disabledRates & 1) == 1) ? .on : .off
        enable500Hz.state = ((disabledRates & 2) == 2) ? .on : .off
        enable250Hz.state = ((disabledRates & 4) == 4) ? .on : .off
        enable125Hz.state = ((disabledRates & 8) == 8) ? .on : .off
        
        // TODO figure out why this is needed
        buttonActionEditor.delegate = self
        
        window?.title = "Editing Profile \(profileId + 1)"
        buttonTable.reloadData()
    }
    
    
    @IBAction func saveAction(_ sender: Any) {
        config[0x40] =
            ((enable1000Hz.state == .on) ? 1 : 0) |
            ((enable500Hz.state == .on) ? 2 : 0) |
            ((enable250Hz.state == .on) ? 4 : 0) |
            ((enable125Hz.state == .on) ? 8 : 0)
        delegate?.profileSaved(id: profileId, config: config, buttons: buttons)
    }

    
    @IBAction func buttonTableDoubleAction(_ sender: Any) {
        if buttonTable.clickedRow == -1 {
            return
        }
        
        let row = buttonTable.clickedRow
        let showAltAction = (buttonTable.clickedColumn == 2)
        if let targetCell = buttonTable.view(atColumn: showAltAction ? 2 : 1, row: row, makeIfNecessary: false) {
            
            // Show this button
            var index = ProfileWindow.ButtonDefinitions[row].0
            if showAltAction {
                index += altButtonOffset
            }
            
            // Spawn the popover
            popover.show(relativeTo: NSRect(), of: targetCell, preferredEdge: NSRectEdge.minY)
            buttonActionEditor.setButton(buttons[index], index: index)
        }
    }
    
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == buttonTable {
            return ProfileWindow.ButtonDefinitions.count
        }
        return -1
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == buttonTable {
            let view = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as! NSTableCellView
            
            switch tableColumn {
            case .some(buttonColumn):
                view.textField?.stringValue = ProfileWindow.ButtonDefinitions[row].1
                return view
            case .some(mainActionColumn):
                let index = ProfileWindow.ButtonDefinitions[row].0
                view.textField?.stringValue = buttons[index]?.description ?? "Off"
                return view
            case .some(altActionColumn):
                let index = ProfileWindow.ButtonDefinitions[row].0 + self.altButtonOffset
                view.textField?.stringValue = buttons[index]?.description ?? "Off"
                return view
            case .some(_):
                return nil
            case .none:
                return nil
            }
        }
        return nil
    }
    
    
    func updateButton(_ button: TM155Button?, forIndex: Int) {
        buttons[forIndex] = button
        buttonTable.reloadData()
    }
    
    func editingDone() {
        popover.close()
    }
    
}
