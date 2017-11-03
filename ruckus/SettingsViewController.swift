//
//  SettingsViewController.swift
//  ruckus
//
//  Created by Gareth on 16/02/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//

import UIKit
import CoreGraphics
import GoogleMobileAds

protocol SelectableCell {
    func openPickerView()
    func closePickerView(_ tableView: UITableView)
    func resetVisibility()
}

protocol ButtonCallDelegate: class {
    func didPressButton(sender: ButtonCell)
}

protocol ClickInfoIconDelegate: class  {
    func didClickInfo(sender: UITableViewCell)
}

protocol ToggleCellDelegate: class {
    func didToggle(sender: ToggleCell, isOn: Bool)
}

protocol SelectClickDelegate: class {
    func didClickSelectLabel(sender: SelectCell, newValue: String)
}

protocol SelectTimeClickDelegate: class {
    func didClickSelectTimeLabel(sender: SelectCellTime, newValue: String)
}

protocol ChangeDifficultyDelegate: class {
    func didChangeDifficulty(sender: DifficultyCell, newValue: Float)
    
    func didReleaseScroll()
}

protocol ChangeScrollDelegate: class {
    func didChangeScrollValue(sender: ScrollCell, newValue: Float)
    
    func didReleaseScroll()
}

enum SettingsError: Error {
    case CouldNotLoadPlist
    case CouldNotGetSettingsKeyFromStore
}

class SettingsViewController: UIViewController, ChangeScrollDelegate, ChangeDifficultyDelegate, ToggleCellDelegate, SelectClickDelegate, UITableViewDataSource, UITableViewDelegate, ClickInfoIconDelegate, ButtonCallDelegate, SelectTimeClickDelegate {

    let tableData: [String: AnyObject]
    let settings: Settings
    // for deciding wich picker is open
    var selectStates: [String:Bool]
    
    var canReachWatch = false
    
    var notificationBridge: WatchNotificationBridge
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var rateButton: UIButton!
    @IBOutlet weak var bannerView: GADBannerView!
    @IBOutlet weak var upgradeButton: UIButton!
    @IBOutlet weak var addContainer: UIView!
    @IBOutlet weak var rateButtonPaid: UIButton!
    @IBOutlet weak var rateAndUpgrade: UIView!
    
    required init?(coder aDecoder: NSCoder) {
        settings = Settings(usingPlist: "Settings")
        
        do {
            // load the Plist as the "base" for how the settings are structured
            tableData = try settings.loadPlist()
        } catch let error {
            fatalError("\(error)")
            // @TODO should throw here
        }
        
        selectStates = [:]
        
        notificationBridge = WatchNotificationBridge.sharedInstance
        

        super.init(coder: aDecoder)
    }
    
    // MARK: lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        
        if PurchasedState.sharedInstance.isPaid || currentReachabilityStatus == .notReachable {
            addContainer.isHidden = true
            rateButtonPaid.isHidden = false
            rateAndUpgrade.isHidden = true
        } else {
            rateButtonPaid.isHidden = true
            rateAndUpgrade.isHidden = false
            if (Flags.live.rawValue == 1) {
                bannerView.adUnitID = AdIdents.settingsBanner.rawValue
            } else {
                bannerView.adUnitID = AdIdents.debugBannerAd.rawValue
            }
            bannerView.rootViewController = self
            
            // get a new ad for the banner
            bannerView.load(GADRequest())
        }
        
        self.navigationController?.isNavigationBarHidden = true
        
        canReachWatch = notificationBridge.sessionReachable()
        
        reloadTableData()
    }
    
    override func viewDidLayoutSubviews() {
        if (PurchasedState.sharedInstance.isPaid || currentReachabilityStatus == .notReachable) {
            self.tableView.contentInset = UIEdgeInsetsMake(0,0,50,0)
        } else {
            self.tableView.contentInset = UIEdgeInsetsMake(0,0,100,0)
        }
    }
    
    override func viewDidLoad() {
        // set up the rate us button
        rateButton.layer.cornerRadius = 2
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTableData),
            name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
            object: nil
        )
        
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // update the settings on the watch
        
    }
    
    // MARK: - Notification functions and reseting table data
    @objc func reloadTableData() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Actions
    @IBAction func clickRate(_ sender: Any) {
        if let url = URL(string: "https://itunes.apple.com/app/id1241774277") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfButtons = canReachWatch ? 2 : 1
        
        switch section {
        case 0:
            return 2
        case 1:
            return 3
        case 2:
            return 3
        case 3:
            return numberOfButtons
        default:
            return 1
        }
    }
    
    // close up and reset the select cells that are not on the screen
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        if cellType == .selectCell || cellType == .selectCellTime {
            if let cell = tableView.cellForRow(at: indexPath) as? SelectableCell {
                let key = selectStateKey(forPath: indexPath)
                selectStates[key]! = false;
                cell.resetVisibility()
            }
        }
        
    }
    
    // close select cells when deselected
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        if cellType == .selectCell || cellType == .selectCellTime {
            if let cell = tableView.cellForRow(at: indexPath) as? SelectableCell {
                let key = selectStateKey(forPath: indexPath)
                selectStates[key]! = false;
                cell.closePickerView(tableView)
            }
        }
    }
    
    // if the user clicks a select type of cell we want to toggle the cell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        
        if cellType == .selectCell || cellType == .selectCellTime {
            if let cell = tableView.cellForRow(at: indexPath) as? SelectableCell {
                let key = selectStateKey(forPath: indexPath)
                
                if selectStates[key]! {
                    cell.closePickerView(tableView)
                    selectStates[key]! = false
                } else {
                    tableView.beginUpdates()
                    selectStates[key]! = true
                    tableView.endUpdates()
                    cell.openPickerView()
                }
            }
        } else {
            closeSelectCells()
        }
        
    }
    
    // set all as closed
    func closeSelectCells() {
        for (key,open) in selectStates {
            // if open
            if open {
                var parts = key.characters.split{$0 == ":"}.map(String.init)
                
                parts[0].remove(at: parts[0].startIndex)
                parts[1].remove(at: parts[1].startIndex)
                
                guard let row = Int(parts[0]), let section = Int(parts[1]) else {
                    return
                }
                
                let indexPath = IndexPath(row: row, section: section)
                if let cell = tableView.cellForRow(at: indexPath) as? SelectableCell {
                    selectStates[key] = false
                    cell.closePickerView(tableView)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let lastSectionTitle = canReachWatch ? "Sync and credits" : "Credits"
        
        switch section {
        case 0:
            return "Sport"
        case 1:
            return "Interval settings"
        case 2:
            return "Extra settings"
        case 3:
            return lastSectionTitle
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.textWhite
        header.backgroundView?.backgroundColor = UIColor.blackOne
    }
    
    // make sure if we will re-render a select cell it gets the right values assigned to it
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        if cellType == .selectCell || cellType == .selectCellTime {
            var storedValue: String
            let cellKey = settings.keyForCell(atIndexPath: indexPath)
            
            do {
                storedValue = try settings.getValue(forKey: cellKey.rawValue)! as! String
            } catch let error {
                fatalError("\(error)")
            }
            
            if cellType == .selectCell {
                if let cell = cell as? SelectCell {
                    
                    guard let data = tableData[cellKey.rawValue], let values = data["possibleValues"] as? [String] else {
                        fatalError("Could not get the data for the picker")
                    }
                    
                    cell.values = values
                    
                    if let selectedIndex = values.index(of: storedValue as String) {
                        cell.picker!.selectRow(selectedIndex, inComponent: 0, animated: false)
                    }
                    
                    // THIS STUPID LINE COST ME HOURS
                    cell.setSource()
                }
                
            } else if cellType == .selectCellTime {
                
                if let cell = cell as? SelectCellTime {
                    
                    
                    let parts = storedValue.components(separatedBy: ":")
                    guard let mins = Int(parts[0]), let seconds = Int(parts[1]) else {
                        return
                    }
                    
                    if let minsPicker = cell.minsPicker, let secondsPicker = cell.secondsPicker {
                        minsPicker.selectRow(mins, inComponent: 0, animated: false)
                        let secondsValue = (seconds == 0) ? 0 : seconds / 5
                        secondsPicker.selectRow(secondsValue, inComponent: 0, animated: false)
                    }
                    
                    cell.setSource()
                }
            }
            
        } else if (cellType == .toggleCell) {
            // set the enabled / disabled
            if let cell =  cell as? ToggleCell {
                let cellKey = settings.keyForCell(atIndexPath: indexPath)
                do {
                    let enabled = try settings.getEnabled(forKey: cellKey.rawValue)!
                    cell.toggleSwitch.isEnabled = enabled as Bool
                } catch let error {
                    fatalError("\(error)")
                }
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        let cell = configureCell(withType: cellType, atIndex: indexPath)
        return cell!
    }
     
    func configureCell(withType type: CellType, atIndex index: IndexPath) -> UITableViewCell? {
        let cellKey = settings.keyForCell(atIndexPath: index)
        
        let storedValue: Any
        
        do {
            storedValue = try settings.getValue(forKey: cellKey.rawValue)!
        } catch let error {
            fatalError("\(error)")
        }
        
        guard let data = tableData[cellKey.rawValue], let label = data["label"] else {
            fatalError("Could not get the data")
        }
        
        switch type {
        case .toggleCell:
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! ToggleCell
            let cellLabel: UILabel = cell.contentView.viewWithTag(1) as! UILabel
            cellLabel.text = label as? String
            cellLabel.textColor = UIColor.textWhite
            
            let toggleState: Bool = storedValue as? String == "1"
            
            cell.toggleSwitch.isOn = toggleState
            
            cell.callDelegate = self
            cell.toggleInfoDelegete = self
            return cell
        case .selectCell:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! SelectCell
            
            let cellLabel: UILabel = cell.contentView.viewWithTag(1) as! UILabel
            cellLabel.text = label as? String
            cellLabel.textColor = UIColor.textWhite
            
            // set the current stored value for the select
            cell.selectedValue!.text = storedValue as? String
            
            cell.callDelegate = self
            cell.toggleInfoDelegete = self
            
            let key = selectStateKey(forPath: index)
            selectStates[key] = false;
            
            return cell
        case .selectCellTime:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! SelectCellTime
            
            let cellLabel: UILabel = cell.contentView.viewWithTag(1) as! UILabel
            cellLabel.text = label as? String
            cellLabel.textColor = UIColor.textWhite
            
            // set the current stored value for the select
            if let currentValue = storedValue as? String {
                cell.selectedValue!.text = currentValue
                
                let parts = currentValue.components(separatedBy: ":")
                cell.currentMins = parts[0]
                cell.currentSeconds = parts[1]
                
            }
            
            cell.callDelegate = self
            cell.toggleInfoDelegete = self
            
            let key = selectStateKey(forPath: index)
            selectStates[key] = false;
            
            return cell

            
        case .difficultyCell:
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! DifficultyCell
            
            cell.callDelegate = self
            
            cell.difficultySlider.value = storedValue as! Float
            
            return cell
        case .scrollCell:
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! ScrollCell
            
            cell.callDelegate = self
            
            cell.slider.value = storedValue as! Float
            
            return cell
        case .buttonCell:
            let cell = tableView.dequeueReusableCell(withIdentifier: type.rawValue, for: index) as! ButtonCell
            if index.row == 0 && canReachWatch {
                cell.button.setTitle("Sync settings with watch", for: .normal)
            } else {
                cell.button.setTitle("View Credits", for: .normal)
            }
            cell.callDelegate = self
            return cell
        }
        
        
    }
    
    // set the height
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = settings.typeOfCell(atIndexPath: indexPath)
        
        if cellType == .selectCell || cellType == .selectCellTime {
            if let open = self.selectStates["r\(indexPath.row):s\(indexPath.section)"] {
                if open {
                    return 280.0
                }
                return 57.0
            }
            return 57.0
        }
        return 57.0
    }
    
    //MARK: - Delegates for types of cell events
    func didToggle(sender: ToggleCell, isOn: Bool) {
        let indexPath = self.tableView.indexPath(for: sender)
        let newValue = isOn ? "1" : "0"
        let cellKey = settings.keyForCell(atIndexPath: indexPath!)
        settings.setValue(newValue, atIndexPath: indexPath!)
        
        // if the newValue is off. check if there are any other toggles this toggle
        // disables
        disableRetaledToggles(forKey: cellKey, currentState: isOn);
        
        // check if we need to close any selected cells that might have been open
        self.closeSelectCells()
    }
    
    // right now it is just one, that is credits button
    func didPressButton(sender: ButtonCell) {
        guard let indexPath = self.tableView.indexPath(for: sender) else {
            return
        }
        if indexPath.row == 0 && canReachWatch {
            // if we can no longer reach the watch, let the user know
            if (!notificationBridge.sessionReachable()) {
                sender.button.setTitle("Cannot reach watch!", for: .normal)
                // then reset the button state after a few seconds short while
                Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                    sender.button.setTitle("Sync settings with watch", for: .normal)
                }
                return
            }
            
            // do the sync settings action the settings
            sender.button.setTitle("Syncing ...", for: .normal)
            sender.button.isEnabled = false
            let settings = UserDefaults.standard.dictionaryRepresentation()
            let cb: (() -> Void) = {
                DispatchQueue.main.async() {
                    // reset the button after the sync
                    sender.button.setTitle("Sync settings with watch", for: .normal)
                    sender.button.isEnabled = true
                }
            }
            notificationBridge.sendMessageWithPayload(.UserDefaultsPayloadFromApp, payload: settings, callback: cb)
            
        } else {
            performSegue(withIdentifier: "showCreditsView", sender: nil)
        }
        
    }
    
    func didClickSelectLabel(sender: SelectCell, newValue: String) {
        // now populate the select with the data for the index and show the picker
        let indexPath = self.tableView.indexPath(for: sender)
        settings.setValue(newValue, atIndexPath: indexPath!)
    }
    
    func didClickSelectTimeLabel(sender: SelectCellTime, newValue: String) {
        let indexPath = self.tableView.indexPath(for: sender)
        settings.setValue(newValue, atIndexPath: indexPath!)
    }
    
    func didChangeDifficulty(sender: DifficultyCell, newValue: Float) {
        let indexPath = self.tableView.indexPath(for: sender)
        settings.setValue(newValue, atIndexPath: indexPath!)
    }
    
    func didChangeScrollValue(sender: ScrollCell, newValue: Float) {
        let indexPath = self.tableView.indexPath(for: sender)
        settings.setValue(newValue, atIndexPath: indexPath!)
    }
    
    func didReleaseScroll() {
        closeSelectCells()
    }
    
    
    // when the user clicks info, show an alert with the information
    func didClickInfo(sender: UITableViewCell) {
        let indexPath = self.tableView.indexPath(for: sender)
        let cellKey = settings.keyForCell(atIndexPath: indexPath!)
        if let descr = tableData[cellKey.rawValue]?["descr"] {
            if let descrString = descr as? String {
                self.showAlert(descrString)
            }
        }
    }
    
    // MARK: - Util functions for cells
    func selectStateKey(forPath indexPath: IndexPath) -> String {
        return "r\(indexPath.row):s\(indexPath.section)"
    }
    
    func showAlert(_ descr: String) {
        let alert = UIAlertController(title: nil, message: descr, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func disableRetaledToggles(forKey cellKey: PossibleSetting, currentState isOn: Bool) {
        if let data = tableData[cellKey.rawValue], let disables = data["disables"] as? [String] {
            
            var subDisables: [PossibleSetting] = []
            
            for toggleName in disables {
                // get cell instance for toggle and disbale / enable it
                guard let setting = PossibleSetting(rawValue: toggleName) else {
                    // @TODO this is a recoverable error
                    print("Could not convert to setting")
                    return
                }
                if let subData = tableData[setting.rawValue], let subDataDisables = subData["disables"] as? [String] {
                    if subDataDisables.count > 0 {
                        subDisables.append(setting)
                    }
                }
                let indexPath = settings.indexPathForToggle(forSetting: setting)
                if let cell = tableView.cellForRow(at: indexPath) as? ToggleCell {
                    cell.toggleSwitch.isEnabled = isOn
                }
                // save the setting (even if not on the screen right now)
                settings.setEnabled(isOn, atIndexPath: indexPath)
            }
            
            for subDisable in subDisables {
                let indexPath = settings.indexPathForToggle(forSetting: subDisable)
                if let cell = tableView.cellForRow(at: indexPath) as? ToggleCell {
                    if (!cell.toggleSwitch.isOn) {
                        self.disableRetaledToggles(forKey: subDisable, currentState: cell.toggleSwitch.isOn)
                    }
                }
            }
            
        }
    }
}
