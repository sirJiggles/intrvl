//
//  UnlockingInterfaceController.swift
//  ruckus
//
//  Created by Gareth on 23.04.17.
//  Copyright © 2017 Gareth. All rights reserved.
//

import WatchKit
import Foundation


class UnlockingInterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // MARK: IB Actions
    
    @IBAction func tapUnlock() {
        crownSequencer.resignFocus()
         WKInterfaceController.reloadRootControllers(withNames: [ControllerNames.ControllsController.rawValue, ControllerNames.TimerController.rawValue, ControllerNames.SettingsController.rawValue], contexts: ["", ControllerActions.Unlock.rawValue, ""])
    }

}
