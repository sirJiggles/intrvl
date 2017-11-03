//
//  FirstViewController.swift
//  ruckus
//
//  Created by Gareth on 01/02/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//
import UIKit
import MKRingProgressView
import HealthKit
import GoogleMobileAds

class TimerViewController: UIViewController, IntervalTimerDelegate, GADInterstitialDelegate {
    
    var ruckusTimer: IntervalTimer
    var lastMode: TimerMode = .working
    var notificationBridge: WatchNotificationBridge
    let intervalTimerSettings: IntervalTimerSettingsHelper
    var activityHelper: CurrentActivityHelper
    
    var interstitial: GADInterstitial!
    var soundPlayer: SoundPlayer?
    
    let workoutStoreHelper = WorkoutStoreHelper.sharedInstance
    let workoutSession = WorkoutSession.sharedInstance
    
    var paused: Bool = false
    var running: Bool = false
    var firstTick: Bool = true
    
    var pauseRingCurrent: Double = 0.0
    var intervalRingCurrent: Double = 0.0
    var doneRingCurrent: Double = 0.0
    
    @IBOutlet weak var timeSectionView: UIView!
    @IBOutlet weak var roundRing: MKRingProgressView!
    @IBOutlet weak var pauseRing: MKRingProgressView!
    @IBOutlet weak var doneRing: MKRingProgressView!
    @IBOutlet weak var roundTimeLabel: UILabel!
    @IBOutlet weak var pauseTimeLabel: UILabel!
    @IBOutlet weak var roundLabel: UILabel!
    
    @IBOutlet weak var timerDivider: UIView!
    @IBOutlet weak var modeLabel: UILabel!
    
    @IBOutlet weak var roundContainer: UIView!
    @IBOutlet weak var roundContainerHeight: NSLayoutConstraint!
    
    @IBOutlet weak var pausedContainer: UIView!
    @IBOutlet weak var pausedContainerHeight: NSLayoutConstraint!
    
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    
    @IBOutlet weak var doneRingLeading: NSLayoutConstraint!
    @IBOutlet weak var doneRingBottom: NSLayoutConstraint!
    @IBOutlet weak var doneRingTo: NSLayoutConstraint!
    @IBOutlet weak var doneRingTrailing: NSLayoutConstraint!
    
    @IBOutlet weak var pauseRingBottom: NSLayoutConstraint!
    @IBOutlet weak var pauseRingTop: NSLayoutConstraint!
    @IBOutlet weak var pauseRingTrailing: NSLayoutConstraint!
    @IBOutlet weak var pauseRingLeading: NSLayoutConstraint!
    
    @IBOutlet weak var sportIcon: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        ruckusTimer = IntervalTimer.sharedInstance
        notificationBridge = WatchNotificationBridge.sharedInstance
        intervalTimerSettings = IntervalTimerSettingsHelper()
        activityHelper = CurrentActivityHelper()
        soundPlayer = SoundPlayer()
        
        super.init(coder: aDecoder)
        ruckusTimer.delegate = self
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.StartWorkoutFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(self,
           selector: #selector(startFromWatch(_:)),
           name: NSNotification.Name(NotificationKey.StartWorkoutFromWatch.rawValue),
           object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.PauseWorkoutFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(self,
           selector: #selector(pauseFromWatch(_:)),
           name: NSNotification.Name(NotificationKey.PauseWorkoutFromWatch.rawValue),
           object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.StopWorkoutFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopFromWatch),
            name: NSNotification.Name(NotificationKey.StopWorkoutFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didGetSettingsSync),
            name: NSNotification.Name(NotificationKey.SettingsSync.rawValue),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.ShowFinishedScreenFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDoneFromWatch(_:)),
            name: NSNotification.Name(NotificationKey.ShowFinishedScreenFromWatch.rawValue),
            object: nil
        )
        
        // set up the full page add, if not paid and have internet connection
        if PurchasedState.sharedInstance.isPaid == false && currentReachabilityStatus != .notReachable{
            createAndLoadInterstitial()
        }
        
        // use monfont spacing so on smaller screens it does not jump
        roundTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 400, weight: UIFontWeightMedium)
        pauseTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 400, weight: UIFontWeightMedium)
        
        // set the size of the rings and spacing for larger screens
        
        // iPadPro 12: 1024.0
        // iPadPro 9.7 / iPadAir / iPadAir2: 768.0
        let size = UIScreen.main.bounds
        
        calcAndSetRingSize(width: size.width, height: size.height)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !running && !paused {
            self.pausedContainerHeight.constant = self.timeSectionView.frame.size.height / 3
            self.roundContainerHeight.constant = (self.timeSectionView.frame.size.height / 3) * 2
        }
        self.view.layoutIfNeeded()
        
        // change the sport icon
        if let sportData = activityHelper.activityData(),let sportImage = sportData["image"] as? UIImage {
            sportIcon.image = sportImage
        }
        firstTick = true
        updateTimer()
    }
    
    // will go into various rotation modes in iPad large portrait
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        

        coordinator.animate(alongsideTransition: { (context) in
            self.calcAndSetRingSize(width: size.width, height: size.height)
        }) { (context) in
            // after view did transition
            switch self.ruckusTimer.currentMode {
            case .preparing, .working, .warmup:
                self.switchTextWork()
            case .stretching, .resting:
                self.switchTextRest()
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // this gets called befoe we segue away
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "workoutFinishedFromTimer" {
            if let summaryData = sender as? [String:String] {
                let vc = segue.destination as! WorkoutFinishedViewController
                vc.summaryData = summaryData
            }
        }
    }
    
    // util functions for updating the timer and so on
    func updateTimer() {
        let settings = intervalTimerSettings.getSettings()
        ruckusTimer.updateSettings(settings: settings)
    }
    
    @objc func didGetSettingsSync() {
        // update the icon displayed if it has chnaged
        if let sportData = activityHelper.activityData(),let sportImage = sportData["image"] as? UIImage {
            sportIcon.image = sportImage
        }
        updateTimer()
    }

    
    // MARK: - Delegate functions for Ruckus timer
    func didTickSecond(time: String, mode: TimerMode) {
        switch mode {
        case .working, .preparing, .warmup:
            roundTimeLabel.text = time
            break
        case .resting, .stretching:
            pauseTimeLabel.text = time
            break
        }
    }
    
    func tickRest(newValue: Double, reset: Bool = false) {
        // update the ring always
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        
        pauseRing.progress = newValue
        pauseRingCurrent = newValue
        CATransaction.commit()
        
        if lastMode != .resting {
            roundTimeLabel.text = "00:00"
            timerDivider.backgroundColor = UIColor.lightBlue
            
            if (!reset && !firstTick) {
                // not training while resting
                workoutSession.pause()
                do {
                    try soundPlayer?.play("notify", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }
            
            // same as working updates in reverse
            UIView.animate(withDuration: 0.2, animations: {
                self.switchTextRest()
                
                self.modeLabel.text = "Resting"
                self.modeLabel.textColor = UIColor.darkestBlue
                
                self.view.layoutIfNeeded()
            })
            lastMode = .resting
        }
        
        if (firstTick) { firstTick = false }
        
    }
    
    func tickPrep(newValue: Double, reset: Bool = false) {
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        
        doneRing.progress = newValue
        doneRingCurrent = newValue
        CATransaction.commit()
        
        if lastMode != .preparing {
            
            workoutSession.pause()
            
            timerDivider.backgroundColor = UIColor.lightOrange
            pauseTimeLabel.text = "00:00"
            
            if (!reset && !firstTick) {
                do {
                    try soundPlayer?.play("notify", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.switchTextWork()
                
                self.roundTimeLabel.textColor = UIColor.lightOrange
                self.modeLabel.text = "Prepare"
                self.modeLabel.textColor = UIColor.darkestOrange
            })
            self.view.layoutIfNeeded()
            lastMode = .preparing
        }
        
        if (firstTick) { firstTick = false }
    }
    
    func tickStretch(newValue: Double, reset: Bool = false) {
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        
        pauseRing.progress = newValue
        pauseRingCurrent = newValue
        CATransaction.commit()
        
        if lastMode != .stretching {
            workoutSession.pause()
            roundTimeLabel.text = "00:00"
            timerDivider.backgroundColor = UIColor.lightBlue
            
            if (!reset && !firstTick) {
                do {
                    try soundPlayer?.play("notify", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.switchTextRest()
                self.modeLabel.text = "Stretch"
                self.modeLabel.textColor = UIColor.darkestBlue
            })
            self.view.layoutIfNeeded()
            lastMode = .stretching
        }
        
        if (firstTick) { firstTick = false }
    }
    
    func tickWarmUp(newValue: Double, reset: Bool = false) {
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        
        roundRing.progress = newValue
        intervalRingCurrent = newValue
        CATransaction.commit()
        
        if lastMode != .warmup {
            workoutSession.resume()
            roundTimeLabel.text = "00:00"
            timerDivider.backgroundColor = UIColor.lightRed
            
            if (!reset && !firstTick) {
                do {
                    try soundPlayer?.play("notify", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.roundTimeLabel.textColor = UIColor.lightRed
                self.modeLabel.text = "Warmup"
                self.modeLabel.textColor = UIColor.darkestRed
            })
            self.view.layoutIfNeeded()
            lastMode = .warmup
        }
        
        if (firstTick) { firstTick = false }
    }
    
    func tickWork(newValue: Double, reset: Bool = false) {
        // update the ring, always
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        roundRing.progress = newValue
        intervalRingCurrent = newValue
        CATransaction.commit()
        
        if lastMode != .working {
            workoutSession.resume()
            pauseTimeLabel.text = "00:00"
            timerDivider.backgroundColor = UIColor.lightRed
            
            if (!reset && !firstTick) {
                do {
                    try soundPlayer?.play("notify", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                if (self.lastMode != .preparing || self.lastMode != .warmup) {
                    // change height of containers
                    self.switchTextWork()
                }
                
                // update colors of divider and mode text
                self.modeLabel.text = "Working"
                self.roundTimeLabel.textColor = UIColor.lightRed
                self.modeLabel.textColor = UIColor.darkestRed
                
                self.view.layoutIfNeeded()
            })
            
            lastMode = .working
        }
        
        if (firstTick) { firstTick = false }
    }
    
    func updateCircuitNumber(to newValue: Double, circuitNumber: Int, reset: Bool = false) {
        CATransaction.begin()
        if (reset) {
            CATransaction.setAnimationDuration(0.1)
        } else {
            CATransaction.setAnimationDuration(1)
        }
        doneRing.progress = newValue
        doneRingCurrent = newValue
        CATransaction.commit()
        roundLabel.text = String(circuitNumber)
    }
    
    // when done the workout
    func finished() {
        showPlayButton()
        paused = false
        running = false
        // only show done if not on watch session, else watch will handle it
        if !notificationBridge.sessionReachable() {
            performSegue(withIdentifier: "workoutFinishedFromTimer", sender: nil)
        }
    }
    
    func aboutToSwitchModes() {
        // dont need to do anything on parent app for this func
    }
    
    // reset the rings
    func didStart() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        doneRing.progress = 0
        roundRing.progress = 0
        pauseRing.progress = 0
        CATransaction.commit()
        pauseRingCurrent = 0.0
        intervalRingCurrent = 0.0
        doneRingCurrent = 0.0
    }
    
    
    
    // MARK: - Delegate for the full page ad
    func createAndLoadInterstitial() {
        if (Flags.live.rawValue == 1) {
            interstitial = GADInterstitial(adUnitID: AdIdents.fullPageOnTimer.rawValue)
        } else {
            interstitial = GADInterstitial(adUnitID: AdIdents.debugFullPage.rawValue)
        }
        
        interstitial.delegate = self
        interstitial.load(GADRequest())
    }
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        // make a new ad
        createAndLoadInterstitial()
        
        // let user porceed with play
        proceedWithPlayClick()
    }

    
    // MARK: - View functions like clicking buttons
    func repositionAmbiguous() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        doneRing.progress = doneRingCurrent + 1
        pauseRing.progress = pauseRingCurrent + 1
        roundRing.progress = intervalRingCurrent + 1
        CATransaction.commit()
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        doneRing.progress = doneRingCurrent
        pauseRing.progress = pauseRingCurrent
        roundRing.progress = intervalRingCurrent
        CATransaction.commit()
    }
    
    func calcAndSetRingSize(width: CGFloat, height: CGFloat) {
        switch (width, height) {
        // large iPAD port
        case (let w, let h) where w == 1024.0 && h == 1366.0:
            resizeRings(widthNewWidth: 70)
            break
        // large, land
        case (let w, let h) where h == 1024.0 && w == 1366.0:
            resizeRings(widthNewWidth: 50)
            break
        // regular port
        case (let w, let h) where w == 768.0 && h == 1024.0:
            resizeRings(widthNewWidth: 60)
            break
        // refular land
        case (let w, let h) where h == 768.0 && w == 1024.0:
            resizeRings(widthNewWidth: 35)
            break
        // 6 / 7 +
        case (let w, _) where w == 414:
            resizeRings(widthNewWidth: 34)
            break
        // 6/7
        case (let w, _) where w == 375:
            resizeRings(widthNewWidth: 28)
            break
            // anything less than 500
        case (let w, _) where w < 500:
            resizeRings(widthNewWidth: 25)
            break
        default:
            repositionAmbiguous()
            break
        }

    }
    
    
    // resize the rings for various devices
    func resizeRings(widthNewWidth width: CGFloat) {
        doneRing.ringWidth = width
        pauseRing.ringWidth = width
        roundRing.ringWidth = width
        
        let spacing = width + 3
        
        pauseRingTop.constant = spacing
        pauseRingBottom.constant = spacing
        pauseRingLeading.constant = spacing
        pauseRingTrailing.constant = spacing
        
        doneRingTo.constant = spacing
        doneRingBottom.constant = spacing
        doneRingLeading.constant = spacing
        doneRingTrailing.constant = spacing
    }
    
    func switchTextRest() {
        self.roundContainerHeight.constant = self.timeSectionView.frame.size.height / 3
        self.pausedContainerHeight.constant = (self.timeSectionView.frame.size.height / 3) * 2
        
        self.pausedContainer.transform  = CGAffineTransform(translationX: 0, y: -(self.timeSectionView.frame.height / 3))
        self.roundContainer.transform = CGAffineTransform(translationX: 0, y: (self.timeSectionView.frame.height / 3) * 2)
    }
    
    func switchTextWork() {
        self.pausedContainerHeight.constant = self.timeSectionView.frame.size.height / 3
        self.roundContainerHeight.constant = (self.timeSectionView.frame.size.height / 3) * 2
        
        // change position of containers
        self.roundContainer.transform  = CGAffineTransform(translationX: 0, y: -(self.timeSectionView.frame.height - (self.roundContainerHeight.constant * 1.5)))
        self.pausedContainer.transform = CGAffineTransform(translationX: 0, y: (self.timeSectionView.frame.height - (self.pausedContainerHeight.constant * 3)))
    }
    
    func hidePlayButton() {
        // animate showing the pause and stop buttons and hiding this one
        UIView.animate(withDuration: 0.2, animations: {
            self.playBtn.transform = CGAffineTransform(scaleX: 0, y: 0)
            self.pauseBtn.transform = CGAffineTransform(scaleX: 0.55, y: 0.55).translatedBy(x: -(0.55 * self.pauseBtn.layer.frame.width), y: 0)
            self.stopBtn.transform = CGAffineTransform(scaleX: 0.55, y: 0.55).translatedBy(x: (0.55 * self.stopBtn.layer.frame.width), y: 0)
            self.view.layoutIfNeeded()
        }) { (done) in
            self.playBtn.isHidden = true
        }
    }
    
    func showPlayButton() {
        self.playBtn.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.playBtn.transform = CGAffineTransform(scaleX: 1, y: 1)
            self.pauseBtn.transform = CGAffineTransform(scaleX: 1, y: 1).translatedBy(x: (0.01 * self.pauseBtn.layer.frame.width), y: 0)
            self.stopBtn.transform = CGAffineTransform(scaleX: 1, y: 1).translatedBy(x: -(0.01 * self.stopBtn.layer.frame.width), y: 0)
            
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func startFromWatch(_ payload: Notification) {
        if let data = payload.userInfo as? [String: NSDate], let timestamp = data["startTime"] {
            DispatchQueue.main.async {
                self.workoutStoreHelper.workoutStartDate = timestamp as Date
                self.startWorkout(timestamp)
            }
        }
    }
    func startWorkout(_ timestamp: NSDate) {
        if running {
            return
        }
        running = true
        paused = false
        do {
            try soundPlayer?.play("start", withExtension: "wav")
        } catch let error {
            fatalError(error.localizedDescription)
        }
        ruckusTimer.start(timestamp)
        hidePlayButton()
    }
    
    
    @objc func stopFromWatch() {
        DispatchQueue.main.async {
            self.stopWorkout()
        }
    }
    func stopWorkout() {
        ruckusTimer.stop()
        lastMode = .working
        roundTimeLabel.textColor = UIColor.lightRed
        showPlayButton()
        paused = false
        running = false
        firstTick = true
    }
    
    @objc func pauseFromWatch(_ payload: Notification) {
        if let data = payload.userInfo as? [String: NSDate], let timestamp = data["pauseTime"] {
            DispatchQueue.main.async {
                do {
                    try self.soundPlayer?.play("pause", withExtension: "wav")
                } catch let error {
                    fatalError(error.localizedDescription)
                }
                self.pauseWorkout(timestamp)
            }
        }
    }
    
    // called from the watch to show the finnished screen when not connected to a watch session
    @objc func showDoneFromWatch(_ payload: Notification) {
        
        // get the summary information and use it to pass to the next screen
        guard let summary = payload.userInfo as? [String:String] else {
            fatalError("summary payload of wrong type for finished screen")
        }
        
        DispatchQueue.main.async {
            // reset the UI and stop the timer!
            self.stopWorkout()
            self.performSegue(withIdentifier: "workoutFinishedFromTimer", sender: summary)
        }
    }
    
    func pauseWorkout(_ timestamp: NSDate?) {
        if paused {
            return
        }
        paused = true
        running = false
        ruckusTimer.pause(timestamp)
        showPlayButton()
    }
    
    func getAuthAndBeginWorkout() {
        
        workoutStoreHelper.getAuth { (authorized, error) -> Void in
            if (authorized) {
                self.workoutStoreHelper.startWorkout()
            } else {
                // iPad
                self.workoutStoreHelper.workoutStartDate = Date()
            }
            // go back to the main thread to start the workout (even if not authorized)
            DispatchQueue.main.async (execute: {
                self.startWorkout(NSDate())
            })
        }
    }
    
    func proceedWithPlayClick() {
        if notificationBridge.sessionReachable() {
            // wait for the watch to tell us it was ok to start the workout (auth etc) we dont start it here
            notificationBridge.sendMessage(.StartWorkoutFromApp, callback: nil)
            // also always start a workout on the phone just incase we loose connection
            // with the watch during it!
            self.workoutStoreHelper.startWorkout()
        } else {
            getAuthAndBeginWorkout()
        }
    }
    
    // interacting with buttons
    @IBAction func clickPause(_ sender: Any) {
        let pauseTime = NSDate()
        if (notificationBridge.sessionReachable()) {
            notificationBridge.sendMessageWithPayload(.PauseWorkoutFromApp, payload: ["pauseTime":pauseTime], callback: nil)
        } else {
            workoutSession.pause()
        }
        do {
            try self.soundPlayer?.play("pause", withExtension: "wav")
        } catch let error {
            fatalError(error.localizedDescription)
        }
        pauseWorkout(pauseTime)
    }
    
    @IBAction func clickStop(_ sender: Any) {
        if notificationBridge.sessionReachable() {
            stopWorkout()
            notificationBridge.sendMessage(NotificationKey.StopWorkoutFromApp, callback: nil)
        } else {
            guard let workoutStartDate = workoutStoreHelper.workoutStartDate else {
                stopWorkout()
                workoutSession.stop(andSave: false)
                return
            }
            
            if Date().timeIntervalSince(workoutStartDate) > 20.0 {
                // just pause the timer for now, it WILL be stopped on the other screen
                pauseWorkout(nil)
                // show the finished screen
                performSegue(withIdentifier: "workoutFinishedFromTimer", sender: nil)
            } else {
                stopWorkout()
                workoutSession.stop(andSave: false)
            }
        }
    }
    
    @IBAction func clickPlay(_ sender: Any) {
        if PurchasedState.sharedInstance.isPaid || currentReachabilityStatus == .notReachable {
            proceedWithPlayClick()
        } else {
            if interstitial == nil {
                proceedWithPlayClick()
            } else {
                if (interstitial.isReady) {
                    interstitial.present(fromRootViewController: self)
                } else {
                    proceedWithPlayClick()
                }
            }
        }
    }
    
}

