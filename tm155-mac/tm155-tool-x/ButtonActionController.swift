//
//  ButtonActionController.swift
//  tm155-tool-x
//
//  Created by Ash Wolf on 28/12/2018.
//  Copyright © 2018 Ash Wolf. All rights reserved.
//

import Cocoa

protocol ButtonActionDelegate: AnyObject {
    func updateButton(_ button: TM155Button?, forIndex: Int)
    func editingDone()
}

class ButtonActionController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTabViewDelegate {
    enum ActionDef {
        case none
        case constant(TM155Button)
        case key
        case overrideDpi
        case overrideSensitivity
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
        ActionDefRef(.key),
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
        ActionDefRef(.group("Controls", [
            ActionDefRef(.constant(.systemControl(.powerDown))),
            ActionDefRef(.constant(.systemControl(.sleep))),
            ActionDefRef(.constant(.systemControl(.wakeUp))),
            ActionDefRef(.constant(.consumerControl(.power))),
            ActionDefRef(.constant(.consumerControl(.sleep))),
            ActionDefRef(.constant(.consumerControl(.menu))),
            ActionDefRef(.constant(.consumerControl(.brightnessUp))),
            ActionDefRef(.constant(.consumerControl(.brightnessDown))),
            ActionDefRef(.constant(.consumerControl(.brightnessMin))),
            ActionDefRef(.constant(.consumerControl(.brightnessMax))),
            ActionDefRef(.constant(.consumerControl(.brightnessAuto))),
            ActionDefRef(.constant(.consumerControl(.channelUp))),
            ActionDefRef(.constant(.consumerControl(.channelDown))),
            ActionDefRef(.constant(.consumerControl(.mediaPlay))),
            ActionDefRef(.constant(.consumerControl(.mediaPause))),
            ActionDefRef(.constant(.consumerControl(.mediaRecord))),
            ActionDefRef(.constant(.consumerControl(.mediaFastForward))),
            ActionDefRef(.constant(.consumerControl(.mediaRewind))),
            ActionDefRef(.constant(.consumerControl(.mediaNextTrack))),
            ActionDefRef(.constant(.consumerControl(.mediaPreviousTrack))),
            ActionDefRef(.constant(.consumerControl(.mediaStop))),
            ActionDefRef(.constant(.consumerControl(.mediaEject))),
            ActionDefRef(.constant(.consumerControl(.mediaPlayOrPause))),
            ActionDefRef(.constant(.consumerControl(.mute))),
            ActionDefRef(.constant(.consumerControl(.bassBoost))),
            ActionDefRef(.constant(.consumerControl(.loudness))),
            ActionDefRef(.constant(.consumerControl(.volumeUp))),
            ActionDefRef(.constant(.consumerControl(.volumeDown))),
            ActionDefRef(.constant(.consumerControl(.bassUp))),
            ActionDefRef(.constant(.consumerControl(.bassDown))),
            ActionDefRef(.constant(.consumerControl(.trebleUp))),
            ActionDefRef(.constant(.consumerControl(.trebleDown))),
            ActionDefRef(.constant(.consumerControl(.consumerControlCfg))),
            ActionDefRef(.constant(.consumerControl(.emailReader))),
            ActionDefRef(.constant(.consumerControl(.calculator))),
            ActionDefRef(.constant(.consumerControl(.localBrowser))),
            ActionDefRef(.constant(.consumerControl(.researchBrowser))),
            ActionDefRef(.constant(.consumerControl(.search))),
            ActionDefRef(.constant(.consumerControl(.home))),
            ActionDefRef(.constant(.consumerControl(.back))),
            ActionDefRef(.constant(.consumerControl(.forward))),
            ActionDefRef(.constant(.consumerControl(.stop))),
            ActionDefRef(.constant(.consumerControl(.refresh))),
            ActionDefRef(.constant(.consumerControl(.bookmarks))),
            ActionDefRef(.constant(.consumerControl(.unkD1))),
            ActionDefRef(.constant(.consumerControl(.unkD2))),
            ActionDefRef(.constant(.consumerControl(.unkD3))),
            ActionDefRef(.constant(.consumerControl(.unkD4))),
            ActionDefRef(.constant(.consumerControl(.unkD5))),
            ActionDefRef(.constant(.consumerControl(.unkD6))),
            ActionDefRef(.constant(.consumerControl(.unkD7))),
            ActionDefRef(.constant(.consumerControl(.unk2C7))),
            ActionDefRef(.constant(.consumerControl(.unk2C8))),
            ActionDefRef(.constant(.consumerControl(.unk1C8))),
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
            ActionDefRef(.constant(.alternateButtonGroup)),
            ActionDefRef(.overrideDpi),
            ActionDefRef(.overrideSensitivity),
            ])),
        ]

    
    @IBOutlet weak var buttonTypeOutline: NSOutlineView!
    public weak var delegate: ButtonActionDelegate?
    private var button: TM155Button?
    private var buttonIndex: Int = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        buttonTypeOutline.reloadData()
        setupTabControls()
    }

    
    func setButton(_ button: TM155Button?, index: Int) {
        self.button = button
        buttonIndex = index
        selectActionInOutline(button)
    }
    
    
    // Action Definition Outline
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? ActionDefRef {
            if case .group(_, let children) = item.d {
                return children[index]
            } else {
                fatalError()
            }
        } else {
            return ButtonActionController.ActionDefinitions[index]
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
            return ButtonActionController.ActionDefinitions.count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let tableColumn = tableColumn {
            if let item = item as? ActionDefRef {
                let text: String
                
                switch item.d {
                case .none: text = "None"
                case .key: text = "Key"
                case .overrideDpi: text = "Override DPI"
                case .overrideSensitivity: text = "Override Sensitivity"
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
        func checkMatch(_ def: ActionDefRef) -> Bool {
            switch def.d {
            case .none:
                if button == nil {
                    return true
                }
            case .constant(let check):
                if button == check {
                    return true
                }
            case .key:
                if case .some(.key(_, _, _)) = button {
                    return true
                }
            case .overrideDpi:
                if case .some(.overrideDpi(_, _)) = button {
                    return true
                }
            case .overrideSensitivity:
                if case .some(.overrideSensitivity(_, _)) = button {
                    return true
                }
            case .group(_, let children):
                if children.contains(where: { checkMatch($0) }) {
                    return true
                }
            }
            return false
        }
        
        var match: ActionDefRef? = nil
        
        func findAndExpand(_ defs: [ActionDefRef]) {
            for def in defs {
                if checkMatch(def) {
                    if case .group(_, let children) = def.d {
                        // This is a group, so we want something inside it
                        buttonTypeOutline.expandItem(def)
                        findAndExpand(children)
                    } else {
                        // This is not a group, so it means we found a match
                        match = def
                    }
                    return
                }
            }
        }
        
        findAndExpand(ButtonActionController.ActionDefinitions)
        
        let row = buttonTypeOutline.row(forItem: match)
        if row == -1 {
            buttonTypeOutline.deselectAll(nil)
        } else {
            let indexSet = IndexSet(integer: row)
            buttonTypeOutline.selectRowIndexes(indexSet, byExtendingSelection: false)
            buttonTypeOutline.scrollRowToVisible(row)
            displayParamsFor(match!, button)
        }
    }
    
    @IBAction func outlineAction(_ sender: Any) {
        if buttonTypeOutline.clickedRow == -1 {
            return
        }
        
        let def = buttonTypeOutline.item(atRow: buttonTypeOutline.clickedRow) as! ActionDefRef

        switch def.d {
        case .group(_, _):
            // for this, we just expand/collapse it
            if buttonTypeOutline.isItemExpanded(def) {
                buttonTypeOutline.collapseItem(def)
            } else {
                buttonTypeOutline.expandItem(def)
            }
            return
        case .none:
            button = nil
        case .constant(let button):
            self.button = button
        case .key:
            button = .key(.init(rawValue: 0), nil, nil)
        case .overrideDpi:
            button = .overrideDpi(x: 20, y: 20)
        case .overrideSensitivity:
            button = .overrideSensitivity(x: 20, y: 20)
        }
        
        displayParamsFor(def, button)
    }

    @IBAction func saveAndFinishEditing(_ sender: Any) {
        // if the user double clicked on a group then do nothing
        if (sender as! NSView) == buttonTypeOutline && buttonTypeOutline.clickedRow != -1 {
            let def = buttonTypeOutline.item(atRow: buttonTypeOutline.clickedRow) as! ActionDefRef
            
            if case .group(_, _) = def.d {
                return
            }
        }
        syncParamsFromControls()
        delegate?.updateButton(button, forIndex: buttonIndex)
        delegate?.editingDone()
    }

    // Type-specific Widgets
    @IBOutlet weak var typeTabView: NSTabView!
    @IBOutlet weak var emptyTab: NSTabViewItem!
    @IBOutlet weak var keyTab: NSTabViewItem!
    @IBOutlet weak var keyTabModifiers: NSPopUpButton!
    @IBOutlet weak var keyTabKey1: NSPopUpButton!
    @IBOutlet weak var keyTabKey2: NSPopUpButton!
    @IBOutlet weak var overrideTab: NSTabViewItem!
    
    // DPI: range 1-41 (step: 200, range 200-8200)
    // Sensitivity: ???
    @IBOutlet weak var overrideFormatter: NumberFormatter!
    @objc dynamic var overrideMin: Int = 0
    @objc dynamic var overrideMax: Int = 0
    @objc dynamic var overrideX: Int = 0
    @objc dynamic var overrideY: Int = 0
    
    @IBAction func toggleState(_ sender: NSMenuItem) {
        sender.state = (sender.state == .on) ? .off : .on
        
        // this is low key rather ugly, but not sure how best to do it
        if sender.menu! == keyTabModifiers.menu! {
            syncKeyModifierFlagsTitle(control: keyTabModifiers)
        }
    }
    
    func setupTabControls() {
        setupKeyModifierFlags(control: keyTabModifiers)
        setupKey(control: keyTabKey1)
        setupKey(control: keyTabKey2)
    }
    
    func setupKeyModifierFlags(control: NSPopUpButton) {
        control.addItem(withTitle: "<Title Item>")

        for elem in TM155KeyModifierFlags.allValues {
            control.addItem(withTitle: elem.description)
            let item = control.lastItem!
            item.tag = Int(elem.rawValue)
            item.target = self
            item.action = #selector(toggleState(_:))
        }
    }
    
    func displayKeyModifierFlags(_ flags: TM155KeyModifierFlags, control: NSPopUpButton) {
        control.title = flags.description
        for elem in TM155KeyModifierFlags.allValues {
            let index = control.indexOfItem(withTag: Int(elem.rawValue))
            if index > -1 {
                control.item(at: index)?.state = flags.contains(elem) ? .on : .off
            }
        }
    }

    func keyModifierFlagsFromControl(_ control: NSPopUpButton) -> TM155KeyModifierFlags {
        var flags = TM155KeyModifierFlags()
        for elem in TM155KeyModifierFlags.allValues {
            let index = control.indexOfItem(withTag: Int(elem.rawValue))
            if control.item(at: index)?.state == .on {
                flags.insert(elem)
            }
        }
        return flags
    }

    func syncKeyModifierFlagsTitle(control: NSPopUpButton) {
        let flags = keyModifierFlagsFromControl(control)
        control.title = flags.description
    }

    func setupKey(control: NSPopUpButton) {
        control.addItem(withTitle: "None")
        control.lastItem?.tag = 0

        for elem in TM155Key.allValues {
            control.addItem(withTitle: elem.description)
            control.lastItem?.tag = Int(elem.rawValue)
        }
    }
    
    func displayKey(_ key: TM155Key?, control: NSPopUpButton) {
        control.selectItem(withTag: Int(key?.rawValue ?? 0))
    }

    func keyFromControl(_ control: NSPopUpButton) -> TM155Key? {
        let tag = control.selectedTag()
        if tag == 0 {
            return nil
        } else {
            return TM155Key(rawValue: UInt8(tag))
        }
    }

    func displayParamsFor(_ def: ActionDefRef, _ button: TM155Button?) {
        switch def.d {
        case .none: typeTabView.selectTabViewItem(emptyTab)
        case .constant(_): typeTabView.selectTabViewItem(emptyTab)
        case .group(_, _): fatalError()
        case .key:
            typeTabView.selectTabViewItem(keyTab)
            if case .some(.key(let modifier, let key1, let key2)) = button {
                displayKeyModifierFlags(modifier, control: keyTabModifiers)
                displayKey(key1, control: keyTabKey1)
                displayKey(key2, control: keyTabKey2)
            }
        case .overrideDpi:
            typeTabView.selectTabViewItem(overrideTab)
            overrideMin = 1
            overrideMax = 41
            overrideFormatter.multiplier = 200
            overrideFormatter.minimum = 1
            overrideFormatter.maximum = 41
            if case .some(.overrideDpi(let x, let y)) = button {
                // force a KVC update so that the textfield will
                // refresh even if the old/new values are the same
                overrideX = 255
                overrideX = Int(x)
                overrideY = 255
                overrideY = Int(y)
            }
        case .overrideSensitivity:
            typeTabView.selectTabViewItem(overrideTab)
            overrideMin = 0
            overrideMax = 255
            overrideFormatter.multiplier = 1
            overrideFormatter.minimum = 0
            overrideFormatter.maximum = 2555
            if case .some(.overrideSensitivity(let x, let y)) = button {
                // force a KVC update so that the textfield will
                // refresh even if the old/new values are the same
                overrideX = 0
                overrideX = Int(x)
                overrideY = 0
                overrideY = Int(y)
            }
        }
    }
    
    func syncParamsFromControls() {
        if case .some(.key(_, _, _)) = button {
            let modifier = keyModifierFlagsFromControl(keyTabModifiers)
            let key1 = keyFromControl(keyTabKey1)
            let key2 = keyFromControl(keyTabKey2)
            button = .key(modifier, key1, key2)
        }
        else if case .some(.overrideDpi(_, _)) = button {
            button = .overrideDpi(x: UInt8(overrideX), y: UInt8(overrideY))
        }
        else if case .some(.overrideSensitivity(_, _)) = button {
            button = .overrideSensitivity(x: UInt8(overrideX), y: UInt8(overrideY))
        }
    }
}

