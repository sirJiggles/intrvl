//
//  CurrentActivityHelper.swift
//  ruckus
//
//  Created by Gareth on 19.05.17.
//  Copyright © 2017 Gareth. All rights reserved.
//

import Foundation

class CurrentActivityHelper {
    
    let sportModel: Sport
    let settings: Settings
    let settingsData: [String: AnyObject]
    
    init() {
        // set up sport model and settings model
        // for finding out what sort of activity we are working with
        sportModel = Sport()
        
        settings = Settings.init(usingPlist: "Settings")
        do {
            settingsData = try settings.loadPlist()
        } catch {
            fatalError("Could not load defaults plist from picker watch")
        }
    }
    
    func activityData() -> [String: Any]? {
        var activityString = ""
        var activityLocation = ""
        
        do {
            activityString = try settings.getValue(forKey: PossibleSetting.sport.rawValue) as! String
            activityLocation = try settings.getValue(forKey: PossibleSetting.location.rawValue) as! String
        } catch let error {
            fatalError("\(error)")
        }
        
        // using sport model try to cast selection to activity type
        if let sportType = sportModel.getSportType(usingString: activityString) {
            let activityType = sportModel.getSport(forType: sportType)
            let sportImage = sportModel.icon(forSportType: sportType)
            
            return [
                "type": activityType,
                "image": sportImage,
                "name": activityString,
                "location": activityLocation
            ]
        }
        
        return nil
    }
    
    
}
