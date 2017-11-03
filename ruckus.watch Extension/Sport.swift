//
//  Sports.swift
//  ruckus
//
//  Created by Gareth on 15.05.17.
//  Copyright © 2017 Gareth. All rights reserved.
//

import HealthKit
import UIKit

enum SportType: String {
    case boxing
    case coreTraining
    case crossTraining
    case dance
    case elliptical
    case fencing
    case flexibility
    case funcStrength
    case gymnastics
    case highIntensity
    case jumpRope
    case kickboxing
    case martialArts
    case mindAndBody
    case metabolicCardio
    case prepAndRecovery
    case stepTraining
    case strength
    case wrestling
    case yoga
    case other
}

struct Sport {
    
    public func getSportType(usingString sport: String) -> SportType? {
        if let sportType = SportType.init(rawValue: sport.camelcaseString) {
            return sportType
        }
        return nil
    }
    
    public func icon(forSportType sport: SportType) -> UIImage {
        switch sport {
        case .coreTraining:
            return #imageLiteral(resourceName: "core")
        case .crossTraining:
            return #imageLiteral(resourceName: "crossfit")
        case .dance:
            return #imageLiteral(resourceName: "dance")
        case .elliptical:
            return #imageLiteral(resourceName: "elliptical")
        case .fencing:
            return #imageLiteral(resourceName: "fencing")
        case .flexibility:
            return #imageLiteral(resourceName: "strecthing")
        case .strength, .funcStrength:
            return #imageLiteral(resourceName: "dumbell")
        case .gymnastics:
            return #imageLiteral(resourceName: "gymnastics")
        case .highIntensity, .other:
            return #imageLiteral(resourceName: "hit")
        case .jumpRope:
            return #imageLiteral(resourceName: "jumprope")
        case .kickboxing, .boxing:
            return #imageLiteral(resourceName: "boxing")
        case .martialArts:
            return #imageLiteral(resourceName: "nunchucks")
        case .mindAndBody, .yoga:
            return #imageLiteral(resourceName: "matt")
        case .metabolicCardio, .prepAndRecovery:
            return #imageLiteral(resourceName: "cardio")
        case .stepTraining:
            return #imageLiteral(resourceName: "stepper")
        case .wrestling:
            return #imageLiteral(resourceName: "wrestling")
        }
    }
    
    public func getSport(forType sportType: SportType) -> HKWorkoutActivityType {
        switch sportType {
        case .boxing:
            return .boxing
        case .coreTraining:
            return .coreTraining
        case .crossTraining:
            return .crossTraining
        case .dance:
            return .dance
        case .elliptical:
            return .elliptical
        case .fencing:
            return .fencing
        case .flexibility:
            return .flexibility
        case .funcStrength:
            return .functionalStrengthTraining
        case .gymnastics:
            return .gymnastics
        case .highIntensity:
            return .highIntensityIntervalTraining
        case .jumpRope:
            return .jumpRope
        case .kickboxing:
            return .kickboxing
        case .martialArts:
            return .martialArts
        case .mindAndBody:
            return .mindAndBody
        case .metabolicCardio:
            return .mixedMetabolicCardioTraining
        case .prepAndRecovery:
            return .preparationAndRecovery
        case .stepTraining:
            return .stepTraining
        case .strength:
            return .traditionalStrengthTraining
        case .wrestling:
            return .wrestling
        case .yoga:
            return .yoga
        case .other:
            return .other
        }
        
    }
}











