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

class ProfileWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, NSOutlineViewDelegate, NSOutlineViewDataSource {
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
    
    enum ActionDef {
        case none
        case constant(TM155Button)
        case group(String, [ActionDefRef])
    }
    
    class ActionDefRef {
        var d: ActionDef
        init (_ def: ActionDef) {
            d = def
        }
    }
    
    static let ActionDefinitions: [ActionDefRef] = [
        ActionDefRef(.none),
        ActionDefRef(.group("Buttons", [
            ActionDefRef(.constant(.mouse(.left))),
            ActionDefRef(.constant(.mouse(.right))),
            ActionDefRef(.constant(.mouse(.middle))),
            ActionDefRef(.constant(.mouse(.button4))),
            ActionDefRef(.constant(.mouse(.button5))),
        ])),
        ActionDefRef(.group("Scrolling", [
            ActionDefRef(.constant(.scroll(.tiltLeft))),
            ActionDefRef(.constant(.scroll(.tiltRight))),
            ActionDefRef(.constant(.scroll(.wheelUp))),
            ActionDefRef(.constant(.scroll(.wheelDown))),
            ActionDefRef(.constant(.mouse(.tiltLeft))),
            ActionDefRef(.constant(.mouse(.tiltRight))),
            ActionDefRef(.constant(.mouse(.wheelUp))),
            ActionDefRef(.constant(.mouse(.wheelDown))),
        ])),
        ActionDefRef(.group("Parameters", [
            ActionDefRef(.constant(.reportRateUp)),
            ActionDefRef(.constant(.reportRateDown)),
            ActionDefRef(.constant(.reportRateCycle)),
            ActionDefRef(.constant(.dpiStageUp)),
            ActionDefRef(.constant(.dpiStageDown)),
            ActionDefRef(.constant(.dpiStageCycle)),
            ActionDefRef(.constant(.profilePrevious)),
            ActionDefRef(.constant(.profileUp)),
            ActionDefRef(.constant(.profileDown)),
            ActionDefRef(.constant(.profileCycle)),
            ActionDefRef(.constant(.profileUnkFF)),
        ])),
        ActionDefRef(.group("Chords", [
            ActionDefRef(.constant(.alternateButtonGroup))
        ])),
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
    
    
    @IBAction func saveAction(_ sender: Any) {
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
            let index = ProfileWindow.ButtonDefinitions[row].0
            editedButtonIndex = index
            if showAltAction {
                editedButtonIndex += altButtonOffset
            }
            
            selectActionInOutline(buttons[editedButtonIndex])
            
            // Spawn the popover
            popover.show(relativeTo: NSRect(), of: targetCell, preferredEdge: NSRectEdge.minY)
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
    
    
    @IBAction func saveEvent(_ sender: Any) {
        buttonTable.reloadData()
    }
    
    
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? ActionDefRef {
            if case .group(_, let children) = item.d {
                return children[index]
            } else {
                fatalError()
            }
        } else {
            return ProfileWindow.ActionDefinitions[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? ActionDefRef {
            if case .group(_, let children) = item.d {
                return !children.isEmpty
            }
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? ActionDefRef {
            if case .group(_, let children) = item.d {
                return children.count
            } else {
                return 0
            }
        } else {
            // this must be the top-level item
            return ProfileWindow.ActionDefinitions.count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let tableColumn = tableColumn {
            if let item = item as? ActionDefRef {
                let text: String
                
                switch item.d {
                case .none: text = "None"
                case .constant(let button): text = button.description
                case .group(let name, _): text = name
                }
                
                if let view = outlineView.makeView(withIdentifier: tableColumn.identifier, owner: self) {
                    let view = view as! NSTableCellView
                    view.textField?.stringValue = text
                    return view
                }
            }
        }
        
        return nil
    }
    
    func selectActionInOutline(_ button: TM155Button?) {
        // this is a really inefficient recursive algorithm
        // but we don't have many definitions so that's OK
        func contains(_ defs: [ActionDefRef]) -> Bool {
            for def in defs {
                switch def.d {
                case .none:
                    if button == nil {
                        return true
                    }
                case .constant(let check):
                    if let button = button {
                        if button == check {
                            return true
                        }
                    }
                case .group(_, let children):
                    if contains(children) {
                        return true
                    }
                }
            }
            return false
        }
        
        var match: ActionDefRef? = nil

        func findAndExpand(_ defs: [ActionDefRef]) {
            for def in defs {
                switch def.d {
                case .none:
                    if button == nil {
                        match = def
                        return
                    }
                case .constant(let check):
                    if let button = button {
                        if button == check {
                            match = def
                            return
                        }
                    }
                case .group(_, let children):
                    if contains(children) {
                        buttonTypeOutline.expandItem(def)
                        findAndExpand(children)
                        return
                    }
                }
            }
        }
        
        findAndExpand(ProfileWindow.ActionDefinitions)
        
        let row = buttonTypeOutline.row(forItem: match)
        if row == -1 {
            buttonTypeOutline.deselectAll(nil)
        } else {
            let indexSet = IndexSet(integer: row)
            buttonTypeOutline.selectRowIndexes(indexSet, byExtendingSelection: false)
            buttonTypeOutline.scrollRowToVisible(row)
        }
    }
    
    @IBAction func outlineDoubleAction(_ sender: Any) {
        if buttonTypeOutline.clickedRow == -1 {
            return
        }
        
        let def = buttonTypeOutline.item(atRow: buttonTypeOutline.clickedRow) as! ActionDefRef
        switch def.d {
        case .none:
            buttons[editedButtonIndex] = nil
            buttonTable.reloadData()
            popover.close()
        case .constant(let button):
            buttons[editedButtonIndex] = button
            buttonTable.reloadData()
            popover.close()
        case .group(_, _):
            // nothing happens when you select a group!
            break
        }
    }
}
