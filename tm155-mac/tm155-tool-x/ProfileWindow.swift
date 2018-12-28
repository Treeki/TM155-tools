//
//  ProfileWindow.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 25/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Cocoa

class ProfileWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, NSOutlineViewDelegate, NSOutlineViewDataSource {
    private var profileId: Int = -1
    private var config: [UInt8] = []
    private var buttons: [TM155Button?] = []
    private let altButtonOffset = 16
    
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
    @IBOutlet weak var buttonTypeOutline: NSOutlineView!
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func setup(profileId: Int, config: [UInt8], buttons: [TM155Button?]) {
        self.profileId = profileId
        self.config = config
        self.buttons = buttons
        
        window?.title = "Editing Profile \(profileId + 1)"
        buttonTable.reloadData()
    }
    
    
    @IBAction func buttonTableDoubleAction(_ sender: Any) {
        if buttonTable.clickedRow == -1 {
            return
        }
        
        let buttonIndex = buttonTable.clickedRow
        let showAltAction = (buttonTable.clickedColumn == 2)
        if let targetCell = buttonTable.view(atColumn: showAltAction ? 2 : 1, row: buttonIndex, makeIfNecessary: false) {
            // Spawn the popover
            popover.show(relativeTo: NSRect.init(), of: targetCell, preferredEdge: NSRectEdge.minY)
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
            switch tableColumn {
            case .some(buttonColumn):
                let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier.init("ButtonCell"), owner: self) as! NSTableCellView
                view.textField?.stringValue = ProfileWindow.ButtonDefinitions[row].1
                return view
            case .some(mainActionColumn):
                let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier.init("MainActionCell"), owner: self) as! NSTableCellView
                let index = ProfileWindow.ButtonDefinitions[row].0
                view.textField?.stringValue = buttons[index]?.description ?? "Off"
                return view
            case .some(altActionColumn):
                let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier.init("AltActionCell"), owner: self) as! NSTableCellView
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
    
    
    @IBAction func saveEvent(_ sender: Any) {
        buttonTable.reloadData()
    }
}
