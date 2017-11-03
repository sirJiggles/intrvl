//
//  InterfaceController.swift
//  ruckus.watch Extension
//
//  Created by Gareth on 27/02/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class TimerController: WKInterfaceController, IntervalTimerDelegate, AppNotificationBridgeProtocol, WKCrownDelegate, WorkoutControllerProtocol {
    
    @IBOutlet var playSection: WKInterfaceGroup!
    @IBOutlet var workingSection: WKInterfaceGroup!
    
    @IBOutlet var timeLabel: WKInterfaceLabel!
    @IBOutlet var modeLabel: WKInterfaceLabel!
    @IBOutlet var intervalLabel: WKInterfaceLabel!
    
    @IBOutlet var heartRateLabel: WKInterfaceLabel!
    @IBOutlet var calorieLabel: WKInterfaceLabel!
    @IBOutlet var heartImage: WKInterfaceImage!
    
    @IBOutlet var sportIcon: WKInterfaceImage!
    
    let workoutStoreHelper = WorkoutStoreHelper.sharedInstance
    let workoutSession = WorkoutSession.sharedInstance
    
    var paused: Bool = false
    var running: Bool = false
    var enabled: Bool = false
    var locked: Bool = false
    
    var BPM: UInt16 = 0
    var animatingHeart = false
    
    // unlock crown data
    let unlockRotationsNeeded = 30
    var unlockRotations = 0
    var unlockTimer: Timer?
    
    let timer = IntervalTimer.sharedInstance
    var lastMode: TimerMode?
    let appNotificationBridge = AppNotificationBridge.sharedInstance
    var activityHelper: CurrentActivityHelper?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // make this the main view in our paged views
        becomeCurrentPage()
        
        DispatchQueue.global().sync {
            self.timer.delegate = self
            
            if (self.timer.running) {
                self.running = true
                self.paused = false
            }
            
            if (self.timer.paused) {
                self.paused = true
                self.running = false
            }
            
            self.appNotificationBridge.delegate = self
            
            if self.appNotificationBridge.messageSession == nil {
                self.appNotificationBridge.setUpSession()
            }
            
            if let contextName = context as? String {
                
                // update UI from the current timer state!
                self.timer.UITick()
                
                switch contextName {
                case ControllerActions.Stop.rawValue:
                    self.stop()
                    if self.appNotificationBridge.sessionReachable() {
                        self.appNotificationBridge.sendMessage(.StopWorkoutFromWatch, callback: nil)
                    }
                    self.lastMode = .working
                    break
                case ControllerActions.Pause.rawValue:
                    let pauseTime = NSDate()
                    if self.appNotificationBridge.sessionReachable() {
                        self.appNotificationBridge.sendMessageWithPayload(.PauseWorkoutFromWatch, payload: ["pauseTime": pauseTime], callback: nil)
                    }
                    self.pause(pauseTime)
                    break
                case ControllerActions.Lock.rawValue:
                    self.locked = true
                    self.disablePlay()
                    break
                case ControllerActions.Unlock.rawValue:
                    self.locked = false
                    self.disablePlay()
                    break
                case ControllerActions.Play.rawValue:
                    let startTime = NSDate()
                    if appNotificationBridge.sessionReachable() {
                        self.appNotificationBridge.sendMessageWithPayload(.StartWorkoutFromWatch, payload: ["startTime": startTime], callback: nil)
                    }
                    DispatchQueue.main.async {
                        self.start(startTime)
                    }
                    break
                default: break
                }
                
            }
        }
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        // update the settings and, if not done already enable the play button
        updateTimerSettings()
        
        if (!enabled && !paused && !running && !locked) {
            enablePlay()
        } else {
            // show the workout if coming on paused state
            if paused {
                disablePlay()
            }
        }
        
        // set the sport icon
        activityHelper = CurrentActivityHelper()
        if let sportData = activityHelper?.activityData(),let sportImage = sportData["image"] as? UIImage {
            sportIcon.setImage(sportImage)
        }
        
        crownSequencer.delegate = self
        
        if (locked) {
            crownSequencer.focus()
        }
        
        workoutStoreHelper.delegate = self
        
        DispatchQueue.global().sync {
            // set up hooks for app button presses via notifications
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(NotificationKey.StartWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.startFromApp),
                name: NSNotification.Name(NotificationKey.StartWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(NotificationKey.PauseWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pauseFromApp(_:)),
                name: NSNotification.Name(NotificationKey.PauseWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(NotificationKey.StopWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.stopFromApp),
                name: NSNotification.Name(NotificationKey.StopWorkoutFromApp.rawValue),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.didGetSettingsUpdate),
                name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
                object: nil
            )
        }

        super.willActivate()
    }
    
    override func didDeactivate() {
        
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @objc func didGetSettingsUpdate() {
        // update the sport icon for the watch app
        if let sportData = activityHelper?.activityData(),let sportImage = sportData["image"] as? UIImage {
            sportIcon.setImage(sportImage)
        }
        
        // update the timer instance to use the new settings
        updateTimerSettings()
    }
    
    // MARK: - Hooks for when watch is ready
    func didSetUpSession() {
        
    }
    
    func couldNotSettupSession() {
        
    }
    
    // update the timer settings using the settings .. mwuha ha ha
    func updateTimerSettings() {
        let intervalTimerSettings = IntervalTimerSettingsHelper()
        let settings = intervalTimerSettings.getSettings()
        timer.updateSettings(settings: settings)
    }
    
    // MARK: - Workout controller delegates
    func didGetCalories(calories: Int) {
        calorieLabel.setText(String(calories))
    }
    
    func didGetHeartRate(heartRate: UInt16) {
        heartRateLabel.setText(String(heartRate))
        
        // set the speed of the beat for the heart rate
        if (!animatingHeart) {
            animatingHeart = true
            BPM = heartRate
            animateHeart()
        } else {
            BPM = heartRate
        }
    }
    
    // recursive func to keep animating the heart
    func animateHeart() {
        
        // if we stop a workout we stop the animation
        if !running || paused || BPM == 0 {
            animatingHeart = false
            BPM = 0
            return
        }
        
        let halfBeat:Double = (60 / Double(BPM)) / 2
        
        animate(withDuration: TimeInterval(halfBeat)) {
            self.heartImage.setAlpha(0.8)
        }
        
        let delay = DispatchTime.now() + Double(Int64(halfBeat * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            
            self?.animate(withDuration: TimeInterval(halfBeat)) {
                self?.heartImage.setAlpha(0.6)
            }
            
            let restartIn = DispatchTime.now() + Double(Int64(halfBeat * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            
            // start it again after half a beat
            DispatchQueue.main.asyncAfter(deadline: restartIn) { [weak self] in
                self?.animateHeart()
            }
        }
        
        
        
    }
    
    // MARK: - Crown delegates
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        if !locked {
            return
        }
        unlockRotations += 1
        
        if unlockRotations == unlockRotationsNeeded {
            unlockRotations = 0
            presentController(withName: ControllerNames.UnlockingController.rawValue, context: nil)
        }
        
    }
    
    func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
        if !locked {
            return
        }
        unlockTimer?.invalidate()
        // wait for a period before making it idle again
        unlockTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            self.unlockRotations = 0
        }
    }
    
    // MARK: - Interval timer delegtes
    func didTickSecond(time: String, mode: TimerMode) {
        DispatchQueue.main.async {
            self.timeLabel.setText(time)
        }
    }
    
    func tickRest(newValue: Double, reset: Bool) {
        if (reset) {
            WKInterfaceDevice.current().play(.notification)
        }
        if (lastMode != .resting) {
            workoutSession.pause()
            DispatchQueue.main.async {
                self.timeLabel.setTextColor(UIColor.lightBlue)
                self.modeLabel.setText("Resting")
                self.modeLabel.setTextColor(UIColor.lightBlue)
            }
            lastMode = .resting
        }
    }
    func tickWork(newValue: Double, reset: Bool) {
        if (reset) {
            WKInterfaceDevice.current().play(.notification)
        }
        if (lastMode != .working) {
            workoutSession.resume()
            DispatchQueue.main.async {
                self.timeLabel.setTextColor(UIColor.lightRed)
                self.modeLabel.setTextColor(UIColor.standardRed)
                self.modeLabel.setText("Working")
            }
            lastMode = .working
        }
        
    }
    func tickPrep(newValue: Double, reset: Bool) {
        if (reset) {
            WKInterfaceDevice.current().play(.notification)
        }
        if (lastMode != .preparing) {
            workoutSession.pause()
            DispatchQueue.main.async {
                self.timeLabel.setTextColor(UIColor.lightOrange)
                self.modeLabel.setText("Preparing")
                self.modeLabel.setTextColor(UIColor.lightOrange)
            }
            lastMode = .preparing
        }
    }
    func tickWarmUp(newValue: Double, reset: Bool) {
        if (reset) {
            WKInterfaceDevice.current().play(.notification)
        }
        if (lastMode != .warmup) {
            workoutSession.resume()
            DispatchQueue.main.async {
                self.timeLabel.setTextColor(UIColor.lightRed)
                self.modeLabel.setText("Warming up")
                self.modeLabel.setTextColor(UIColor.standardRed)
            }
            lastMode = .warmup
        }
        
    }
    func tickStretch(newValue: Double, reset: Bool) {
        if (reset) {
            WKInterfaceDevice.current().play(.notification)
        }
        if (lastMode != .stretching) {
            workoutSession.pause()
            DispatchQueue.main.async {
                self.timeLabel.setTextColor(UIColor.lightBlue)
                self.modeLabel.setText("Stretching")
                self.modeLabel.setTextColor(UIColor.lightBlue)
            }
            lastMode = .stretching
        }
    }
    func updateCircuitNumber(to: Double, circuitNumber: Int, reset: Bool) {
        DispatchQueue.main.async {
            self.intervalLabel.setText(String(circuitNumber))
        }
    }
    
    func finished() {
        WKInterfaceDevice.current().play(.success)
        resetUI()
        running = false
        paused = false
        workoutSession.pause()
        presentController(withName: ControllerNames.FinishedController.rawValue, context: nil)
        
    }
    
    func didStart() {
        // dont need anything here
    }
    
    func aboutToSwitchModes() {
        WKInterfaceDevice.current().play(.start)
    }
    
    // MARK: - general class functions
    func resetLabel() {
        DispatchQueue.main.async {
            self.timeLabel.setText("00:00");
        }
    }
    
    func showPreparing() {
        enabled = false
        DispatchQueue.main.async {
            self.workingSection.setHidden(false)
            self.workingSection.setAlpha(0.4)
            self.playSection.setHidden(true)
        }
    }
    
    func disablePlay() {
        enabled = false
        DispatchQueue.main.async {
            self.playSection.setHidden(true)
            self.workingSection.setHidden(false)
            self.workingSection.setAlpha(1)
        }
    }
    
    func enablePlay() {
        DispatchQueue.main.async {
            self.playSection.setHidden(false)
            self.workingSection.setHidden(true)
        }
        enabled = true
    }
    
    func resetUI() {
        resetLabel()
        enablePlay()
        DispatchQueue.main.async {
            self.timeLabel.setTextColor(UIColor.lightRed)
            self.modeLabel.setText("Working")
            self.modeLabel.setTextColor(UIColor.lightestRed)
            self.heartRateLabel.setText("---")
            self.calorieLabel.setText("0")
            self.intervalLabel.setText("0")
        }
        lastMode = .working
    }
    
    func dismissThis() {
        // dont need to do anything, this is just a handle for getting rid of messages
    }
    
    func getAuthAndBeginWorkout() {
        
        // hide the play button right away and start the preparing countdown
        self.showPreparing()
        
        // first check if there is no connection to the phone and the user previsouly
        // did not give auth, if this is the case we simply cannot proceed so we need ot let them
        // know
        if !appNotificationBridge.sessionReachable() {
            if workoutStoreHelper.wasPreviouslyAuthorised() == .notDetermined {
                self.presentAlert(withTitle: "Unable to get auth status", message: "For the first time only you need to be connected to the phone to request authorization to health kit. After giving permission you can use the watch without the phone.", preferredStyle: .alert, actions: [
                    WKAlertAction(title: "Close", style: .cancel, handler: dismissThis )
                    ])
            }
        }
        
        workoutStoreHelper.getAuth { (authorized, error) -> Void in
            if (!authorized) {
                // in this case we cannot procceed, we let the users know we need
                // health access form the parent app. This should not happen but
                // seems to be happneing in watch os 4 beta prevew :(
                
                self.presentAlert(withTitle: "Need health kit auth", message: "Was unable to determine health kith authorization status. Please open the parent app and press play (while not connected to the watch) from there to grant watch access (should only need to do this once)", preferredStyle: .alert, actions: [
                    WKAlertAction(title: "Close", style: .cancel, handler: self.dismissThis )
                    ])
                return
            }

            self.workoutStoreHelper.startWorkout()
            
            DispatchQueue.main.async {
                let startTime = NSDate()
                
                if self.appNotificationBridge.sessionReachable() {
                    self.appNotificationBridge.sendMessageWithPayload(.StartWorkoutFromWatch, payload: ["startTime": startTime], callback: nil)
                }
                self.start(startTime)
            }
           
        }
    }
    
    func reloadViewControllers(withAction action : ControllerActions) {
        WKInterfaceController.reloadRootControllers(withNames: [ControllerNames.ControllsController.rawValue, ControllerNames.TimerController.rawValue, ControllerNames.SettingsController.rawValue], contexts: ["", action.rawValue, ""])
    }
    
    // MARK: - start stop and play controlls / functions
    
    func startWorkout() {
        // must be starting from scratch
        if (!paused) {
            getAuthAndBeginWorkout()
        } else {
            let startTime = NSDate()
            if appNotificationBridge.sessionReachable() {
                appNotificationBridge.sendMessageWithPayload(.StartWorkoutFromWatch, payload: ["startTime": startTime], callback: nil)
            }
            start(startTime)
        }
    }
    
    @objc func startFromApp() {
        DispatchQueue.main.async {
            self.startWorkout()
        }
    }
    func start(_ timestamp: NSDate) {
        if running {
            return
        }
        running = true
        if paused {
            paused = false
            workoutSession.resume()
        }
        disablePlay()
        WKInterfaceDevice.current().play(.success)
        DispatchQueue.global().sync {
            self.timer.start(timestamp)
        }
    }
    
    @objc func pauseFromApp(_ payload: NSNotification) {
        if let data = payload.userInfo as? [String: NSDate], let timestamp = data["pauseTime"] {
            DispatchQueue.main.async {
                self.pause(timestamp)
            }
        }
    }
    
    func pause(_ timestamp: NSDate?) {
        if paused {
            return
        }
        // check if should reset the view controllers
        if locked {
            reloadViewControllers(withAction: ControllerActions.Pause)
            return
        }
        paused = true
        running = false
        locked = false
        timer.pause(timestamp)
        workoutSession.pause()
    }
    
    @objc func stopFromApp() {
        DispatchQueue.main.async {
            self.stop()
        }
    }
    func stop(playNotification: Bool = true) {
        if (!running && !paused) {
            return
        }
        // check if should reset the view controllers
        if locked {
            reloadViewControllers(withAction: ControllerActions.Stop)
            return
        }
        WKInterfaceDevice.current().play(.stop)
        running = false
        paused = false
        locked = false
        // only pause as stopping involves saving
        workoutSession.pause()
        resetUI()
        
        // just incase we have no workout start date ..
        guard let workoutStartDate = workoutStoreHelper.workoutStartDate else {
            timer.stop()
            workoutSession.stop(andSave: false)
            return
        }
        
        // if the duration of the workout is longer than 30 seconds, show the done screen, else
        // could have been a mistake so just stop the workout
        if Date().timeIntervalSince(workoutStartDate) > 20.0 {
            // just pause the timer for now, it WILL be stopped on the other screen
            timer.pause(nil)
            // show the finished screen
            presentController(withName: ControllerNames.FinishedController.rawValue, context: nil)
        } else {
            timer.stop()
            workoutSession.stop(andSave: false)
        }
        
    }
    
    // MARK: - IB actions
    
    @IBAction func tapPlayResume() {
        if (!enabled || running) {
            return
        }
        startWorkout()
    }
    
    
    // debug for unlocking testing
    @IBAction func tapThat() {
        presentController(withName: ControllerNames.UnlockingController.rawValue, context: nil)
    }
    

}
