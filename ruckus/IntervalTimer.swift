//
//  Timer.swift
//  ruckus
//
//  Created by Gareth on 06/03/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//

import Foundation
import UIKit

protocol Timeable {
    func start(_ timestamp: NSDate)
    func stop(updateDisplay: Bool)
    func pause(_ timestamp: NSDate?)
    func tickSecond()
}

protocol IntervalTimerDelegate: class {
    func didTickSecond(time: String, mode: TimerMode)
    func aboutToSwitchModes()
    func tickRest(newValue: Double, reset: Bool)
    func tickWork(newValue: Double, reset: Bool)
    func tickPrep(newValue: Double, reset: Bool)
    func tickWarmUp(newValue: Double, reset: Bool)
    func tickStretch(newValue: Double, reset: Bool)
    func updateCircuitNumber(to: Double, circuitNumber: Int, reset: Bool)
    func finished()
    func didStart()
}

protocol IntervalTimerStateChangeDelegate: class {
    func didPause()
    func didStop()
    func didPlay()
}

// the various states the timer could be in
enum TimerMode: String {
    case working
    case resting
    case preparing
    case warmup
    case stretching
}

class IntervalTimer: NSObject, Timeable {
    var currentMode: TimerMode = .warmup
    
    weak var delegate: IntervalTimerDelegate?
    
    weak var stateChangeDelegate: IntervalTimerStateChangeDelegate?

    var tickerSecond: Timer!
    var startTime: TimeInterval!
    var pausedTimes: [TimeInterval] = []
    var pauseStartTime: TimeInterval!
    var intervalsDone: Double = 0.0
    var firstTick: Bool = true
    
    var paused: Bool = false
    var running: Bool = false
    
    var timePassed: Int = 0
    
    //  values for the timer from the settings model (default values from settings file)
    var intervals: Double = 5.0
    var intervalTime: Double = 150.0 // 2:30
    var restTime: Double = 30.0
    var prepTime: Double = 30.0
    var warmupTime: Double = 180.0 // 3:00
    var stretchTime: Double = 180.0 // 3:00
    
    var intervalProgress: Double = 0
    var restProgress: Double = 0
    var doneProgress: Double = 0
    var prepProgress: Double = 0
    var stretchProress: Double = 0
    var warmUpProgress: Double = 0
    var secondsToDisplay = 0
    var minsToDisplay = 0
    
    var userDefaults: UserDefaultsHelper
    
    var debug = false
    
    static let sharedInstance = IntervalTimer()
    
    override init() {
        userDefaults = UserDefaultsHelper()
        super.init()
    }
    
    func updateSettings(settings: [String: String]) {
        
        if debug {
            intervalTime = 5.0
            restTime = 5.0
            warmupTime = 5.0
            prepTime = 5.0
            stretchTime = 5.0
            intervals = 2
            return
        }
        
        if let intervalTime = settings[PossibleSetting.roundTime.rawValue] {
            self.intervalTime = intervalTime.stringTimeToDouble()
        }
        if let restTime = settings[PossibleSetting.pauseTime.rawValue] {
            self.restTime = restTime.stringTimeToDouble()
        }
        if let prepTime = settings[PossibleSetting.preperationTime.rawValue] {
            self.prepTime = prepTime.stringTimeToDouble()
        }
        if let warmupTime = settings[PossibleSetting.warmUpTime.rawValue] {
            self.warmupTime = warmupTime.stringTimeToDouble()
        }
        if let stretchTime = settings[PossibleSetting.stretchTime.rawValue] {
            self.stretchTime = stretchTime.stringTimeToDouble()
        }
        if let intervals = settings[PossibleSetting.rounds.rawValue] {
            self.intervals = Double(intervals)!
        }
    }
    
    // this is only called from the watch
    func UITick() {
        delegate?.updateCircuitNumber(to: doneProgress, circuitNumber: Int(intervalsDone), reset: false)
        
        switch currentMode {
        case .preparing:
            delegate?.tickPrep(newValue: prepProgress, reset: false)
        case .resting:
            delegate?.tickRest(newValue: restProgress, reset: false)
        case .stretching:
            delegate?.tickStretch(newValue: stretchProress, reset: false)
        case .warmup:
            delegate?.tickWarmUp(newValue: warmUpProgress, reset: false)
        case .working:
            delegate?.tickWork(newValue: intervalProgress, reset: false)
        }
        
        callUpdateText(withSeconds: secondsToDisplay, andMins: minsToDisplay)
    }
    
    func start(_ timestamp: NSDate) {
        running = true
        
        if (!paused) {
            delegate?.didStart()
        } else {
            // add the duration paused to the pausedTimes array
            pausedTimes.append(NSDate().timeIntervalSinceReferenceDate - pauseStartTime)
        }
        startTimers(timestamp)
        
        stateChangeDelegate?.didPlay()
    }
    
    @objc func startTimersFromTimer() {
        startTimers(nil);
    }
    
    func startTimers(_ timestamp: NSDate?) {
        // get the time we started only if not paused
        if (!paused) {
            if let stamp = timestamp {
                startTime = stamp.timeIntervalSinceReferenceDate
            } else {
                startTime = NSDate().timeIntervalSinceReferenceDate
            }
            
        } else {
            // reset the paused bool, as we are now resuming
            paused = false
        }
        
        // handle the possibility warm up, prep time and stretch time are 0
        if (currentMode == .warmup && warmupTime == 0.0) {
            currentMode = .stretching
        }
        if (currentMode == .stretching && stretchTime == 0.0) {
            currentMode = .preparing
        }
        if (currentMode == .preparing && prepTime == 0.0) {
            currentMode = .working
        }
        
        tickSecond()
        
        tickerSecond = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(tickSecond), userInfo: nil, repeats: true)
    }
    
    func stop(updateDisplay: Bool = true) {
        invalidateTickers()
        
        // reset all values
        intervalProgress = 0
        restProgress = 0
        doneProgress = 0
        prepProgress = 0
        warmUpProgress = 0
        stretchProress = 0
        firstTick = true
        intervalsDone = 0
        currentMode = .warmup
        paused = false
        running = false
        pausedTimes = []
        secondsToDisplay = 0
        minsToDisplay = 0
        
        // call delegates to update the rings
        if (updateDisplay) {
            delegate?.tickRest(newValue: 0, reset: true)
            delegate?.tickWork(newValue: 0, reset: true)
            delegate?.updateCircuitNumber(to: 0, circuitNumber: 0, reset: true)
        }
        
        stateChangeDelegate?.didStop()
    }
    
    func pause(_ timestamp: NSDate?) {
        if paused {
            return
        }
        paused = true
        
        // pause time is either now or optional timestamp
        let stamp = timestamp ?? NSDate()
        pauseStartTime = stamp.timeIntervalSinceReferenceDate
        invalidateTickers()
        
        stateChangeDelegate?.didPause()
    }
    
    func invalidateTickers() {
        tickerSecond?.invalidate()
    }
    
    // reset ticker, used for when switching modes and so on (also, wait for a second before starting things up again)
    func switchMode() {
        self.invalidateTickers()
        pausedTimes = []
        firstTick = true
        
        tickerSecond = Timer.scheduledTimer(
            timeInterval: 0,
            target: self,
            selector: #selector(startTimersFromTimer),
            userInfo: nil,
            repeats: false
        )
    }
    
    func increaseIntervals() {
        doneProgress = doneProgress + (1 / intervals)
        intervalsDone += 1.0
        delegate?.updateCircuitNumber(to: doneProgress, circuitNumber: Int(intervalsDone), reset: false)
    }
    
    func intervalComplete(overflow: Double) {
        if intervalsDone < intervals {
            currentMode = .resting
            restProgress = overflow
            delegate?.tickWork(newValue: 0, reset: true)
            switchMode()
        } else {
            delegate?.updateCircuitNumber(to: 1, circuitNumber: Int(intervals), reset: false)
            delegate?.finished()
            // just pause the timer as the finished screens will handle stopping it
            self.pause(nil)
        }
    }
    
    func restComplete(overflow: Double) {
        increaseIntervals()
        currentMode = .working
        intervalProgress = overflow
        delegate?.tickRest(newValue: 0, reset: true)
        self.switchMode()
    }
    
    func warmUpComplete(overflow: Double) {
        currentMode = .stretching
        stretchProress = overflow
        delegate?.tickWarmUp(newValue: 0, reset: true)
        self.switchMode()
    }
    
    func stretchComplete(overflow: Double) {
        currentMode = .preparing
        prepProgress = overflow
        delegate?.tickRest(newValue: 0, reset: true)
        self.switchMode()
    }
    
    func prepComplete(overflow: Double) {
        currentMode = .working
        intervalProgress = overflow
        delegate?.tickPrep(newValue: 0, reset: true)
        self.switchMode()
    }
    
    // go through all the times that the timer was paused and add them together, this gets a duration
    // that the timer may have been paused during a workout
    func getTotalTimePaused() -> TimeInterval {
        var totalPausedTime: TimeInterval = 0.0
        if pausedTimes.count > 0 {
            for time in pausedTimes {
               totalPausedTime += time
            }
        }
        return totalPausedTime
    }
    
    func callUpdateText(withSeconds seconds: Int, andMins mins: Int) {
        let timeStringForDisplay = String.localizedStringWithFormat("%02d:%02d", mins, seconds)
        delegate?.didTickSecond(time: timeStringForDisplay, mode: currentMode)

    }
    
    //MARK: Ticker functions
    @objc func tickSecond() {
        let currentTime = NSDate().timeIntervalSinceReferenceDate
        var elapsedTime: Double = currentTime - startTime
        
        let timeSpentPaused = getTotalTimePaused()
        
        if timeSpentPaused > 0.0 {
            elapsedTime -= timeSpentPaused
        }
        
        var secondsLeft = 0
        let secondsPassed = Int(round(elapsedTime))
        
        switch currentMode {
        case .resting:
            secondsLeft = (Int(restTime) - secondsPassed)
        case .preparing:
            secondsLeft = (Int(prepTime) - secondsPassed)
        case .stretching:
            secondsLeft = (Int(stretchTime) - secondsPassed)
        case .warmup:
            secondsLeft = (Int(warmupTime) - secondsPassed)
        case .working:
            secondsLeft = (Int(intervalTime) - secondsPassed)
        }
        
        secondsToDisplay = (secondsLeft % 60)
        minsToDisplay = (secondsLeft / 60) % 60
        
        callUpdateText(withSeconds: secondsToDisplay, andMins: minsToDisplay)
        
        let doubleSeconds = Double(secondsPassed)
        
        switch currentMode {
        case .working:
            intervalProgress = doubleSeconds / intervalTime
            
            // if this was the first time we went into work mode
            if intervalsDone == 0 {
                delegate?.updateCircuitNumber(to: 0, circuitNumber: 1, reset: false)
                intervalsDone += 1.0
            }
            
            delegate?.tickWork(newValue: intervalProgress, reset: false)
            
            // about to complete interval check
            if doubleSeconds + 2 == intervalTime || doubleSeconds + 1 == intervalTime {
                // dont notify if about to finish
                if (intervalProgress + 1 != intervals) {
                    delegate?.aboutToSwitchModes()
                }
            }
            
            if doubleSeconds - 1 >= intervalTime {
                intervalComplete(overflow: doubleSeconds - intervalTime )
            }
            break
        case .resting:
            restProgress = doubleSeconds / restTime
            
            delegate?.tickRest(newValue: restProgress, reset: false)
            
            // about to complete interval check
            if doubleSeconds + 2 == restTime || doubleSeconds + 1 == restTime {
                delegate?.aboutToSwitchModes()
            }
            if doubleSeconds - 1 >= restTime {
                restComplete(overflow: doubleSeconds - restTime)
            }
            break
        case .preparing:
            prepProgress = doubleSeconds / prepTime
            
            delegate?.tickPrep(newValue: prepProgress, reset: false)
            
            if doubleSeconds + 2 == prepTime || doubleSeconds + 1 == prepTime {
                delegate?.aboutToSwitchModes()
            }
            
            if doubleSeconds - 1 >= prepTime {
                prepComplete(overflow: doubleSeconds - prepTime)
            }
            break
        case .warmup:
            warmUpProgress = doubleSeconds / warmupTime
            
            delegate?.tickWarmUp(newValue: warmUpProgress, reset: false)
            
            if doubleSeconds + 2 == warmupTime || doubleSeconds + 1 == warmupTime {
                delegate?.aboutToSwitchModes()
            }
            
            if doubleSeconds - 1 >= warmupTime {
                warmUpComplete(overflow: doubleSeconds - warmupTime)
            }
            break
        case .stretching:
            stretchProress = doubleSeconds / stretchTime
            
            delegate?.tickStretch(newValue: stretchProress, reset: false)
            
            if doubleSeconds + 2 == stretchTime || doubleSeconds + 1 == stretchTime {
                delegate?.aboutToSwitchModes()
            }
            
            if doubleSeconds - 1 >= stretchTime {
                stretchComplete(overflow: doubleSeconds - stretchTime)
            }
            break
        }
        
        firstTick = false
    }
    
}
