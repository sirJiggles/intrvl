//
//  WorkoutFinishedViewController.sift
//  ruckus
//
//  Created by Gareth on 28/03/2017.
//  Copyright © 2017 Gareth. All rights reserved.
//

import UIKit
import GoogleMobileAds
import HealthKit

class WorkoutFinishedViewController: UIViewController, WorkoutSummeryProtocol {
    
    @IBOutlet weak var sportName: UILabel!
    @IBOutlet weak var sportIcon: UIImageView!
    @IBOutlet weak var time: UILabel!
    @IBOutlet weak var heartRate: UILabel!
    @IBOutlet weak var calories: UILabel!
    @IBOutlet weak var intervals: UILabel!
    @IBOutlet weak var sportIconContainer: UIView!
    @IBOutlet weak var bannerView: GADBannerView!
    @IBOutlet weak var adContainer: UIView!
    @IBOutlet weak var bottomSpace: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIButton!
    
    // bottom banners
    @IBOutlet weak var controlsSave: UIToolbar!
    @IBOutlet weak var controlsClose: UIToolbar!
    
    
    // rows for the heart rate and calories, if we get this data we will show
    @IBOutlet weak var calRow: UIView!
    @IBOutlet weak var heartRateRow: UIView!
    @IBOutlet weak var heartCalDivider: UIView!
    
    
    let activityHelper: CurrentActivityHelper
    let workoutStoreHelper = WorkoutStoreHelper.sharedInstance
    let workoutSession = WorkoutSession.sharedInstance
    let timerController = IntervalTimer.sharedInstance
    let notificationBridge = WatchNotificationBridge.sharedInstance
    
    var soundPlayer: SoundPlayer?
    
    var summaryData: [String:String]?
    
    required init?(coder aDecoder: NSCoder) {
        activityHelper = CurrentActivityHelper()
        super.init(coder: aDecoder)
        workoutStoreHelper.summeryDelegate = self
        soundPlayer = SoundPlayer()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // listen to the ability to dismiss from watch
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name(NotificationKey.DismissFinishedScreenFromWatch.rawValue),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissFromWatch),
            name: NSNotification.Name(NotificationKey.DismissFinishedScreenFromWatch.rawValue),
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        sportIconContainer.layer.cornerRadius = 45
        sportIconContainer.layer.shadowOffset =  CGSize(width: 0, height: 4)   // CGSizeMake(0, 1)
        sportIconContainer.layer.shadowColor = UIColor.black.cgColor
        sportIconContainer.layer.shadowRadius = 2
        sportIconContainer.layer.shadowOpacity = 1
        sportIconContainer.clipsToBounds = true
        sportIconContainer.layer.masksToBounds = false
        
        if PurchasedState.sharedInstance.isPaid || currentReachabilityStatus == .notReachable {
            adContainer.isHidden = true
            bottomSpace.constant = 50
        } else {
            if (Flags.live.rawValue == 1) {
                bannerView.adUnitID = AdIdents.BannerOnFinished.rawValue
            } else {
                bannerView.adUnitID = AdIdents.debugBannerAd.rawValue
            }
            bannerView.rootViewController = self
            
            // get a new ad for the banner
            bannerView.load(GADRequest())
        }
        
        // icon and name for the sport
        let activityHelper = CurrentActivityHelper()
        if let sportData = activityHelper.activityData(),let sportImage = sportData["image"] as? UIImage, let activityName = sportData["name"] as? String {
            sportIcon.image = sportImage
            sportName.text = activityName
        }
        
        // get the interval data from the instance of the timer
        let intervalsCount = timerController.intervalsDone
        
        // now we can stop the timer, we have the data we need (for intervals)
        timerController.stop()
        
        
        // if we already have summary data just use it
        if summaryData != nil {
            processWorkoutDataPayloadFromWatch()
            return
        }

        intervals.text = String(Int(intervalsCount))
        
        
        // get the workout data from the context
        let totals = workoutStoreHelper.getWorkoutTotals()
        if let calCount = totals["kCal"] {
            if calCount != 0 {
                calRow.isHidden = false
                calories.text = String(Int(calCount))
            }
        }
        
        var totalTime: Int
        
        if let startDate = workoutStoreHelper.workoutStartDate {
            totalTime = Int(Date().timeIntervalSince(startDate))
        } else {
            totalTime = 0
        }
        
        
        // convert the time to something we can display
        var timeMins = totalTime / 60
        let timeSeconds = totalTime % 60
        if timeMins > 60 {
            let timeHours = timeMins / 60
            timeMins = timeMins % 60
            time.text = String.localizedStringWithFormat("%2d:%02d:%02d", timeHours, timeMins, timeSeconds)
        } else {
            time.text = String.localizedStringWithFormat("%02d:%02d", timeMins, timeSeconds)
        }
        
        // check what controls we should show
        if !HKHealthStore.isHealthDataAvailable() {
            controlsClose.isHidden = false
            controlsSave.isHidden = true
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        do {
            try self.soundPlayer?.play("finished", withExtension: "wav")
        } catch  {
            // do nothing if there is an error playing the sound, is not the end of the world!
//            fatalError(error.localizedDescription)
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Workout controller summery delegate functions
    func didSaveWorkout() {
        saveButton.isEnabled = true
        saveButton.setTitle("Save", for: .normal)
        resetUI()
        dismiss(animated: true, completion: nil)
    }
    
    func couldNotSaveWorkout() {
        // @TODO build
    }
    
    // MARK: - listen to events from watch
    @objc func dismissFromWatch() {
        // discard local workout session at this stage, was saved on watch
        workoutSession.stop(andSave: false)
        dismiss(animated: true, completion: nil)
    }
    
    func processWorkoutDataPayloadFromWatch() {
        guard let data = summaryData else {
            fatalError("was no summary data to process")
        }
        // only if we get certain vals to we show certain fields
        if let heartRateText = data["heart"] {
            heartRateRow.isHidden = false
            heartRate.text = heartRateText
            heartCalDivider.isHidden = false
        }
        if let caloriesText = data["cal"] {
            calRow.isHidden = false
            calories.text = caloriesText
            heartCalDivider.isHidden = false
        }
        // should always get time and intervals
        if let intervalsText = data["interval"], let timeText = data["time"] {
            intervals.text = intervalsText
            time.text = timeText
        }
    }
    
    // MARK: - UI functions
    private func resetUI() {
        calRow.isHidden = true
        heartRateRow.isHidden = true
        time.text = "0:00"
        intervals.text = "0"
        heartRate.text = "0"
        calories.text = "0"
        summaryData = nil
    }
    
    // MARK: - IB Actions
    @IBAction func didTapDiscard(_ sender: Any) {
        resetUI()
        if (notificationBridge.sessionReachable()) {
            notificationBridge.sendMessage(.DismissFinishedScreenFromApp, callback: nil)
        } else {
            workoutSession.stop(andSave: false)
        }
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didTapSave(_ sender: Any) {
        saveButton.isEnabled = false
        saveButton.setTitle("Saving ...", for: .normal)
        if (notificationBridge.sessionReachable()) {
            notificationBridge.sendMessage(.SaveFromFinishedScreenApp, callback: nil)
        } else {
            workoutSession.stop(andSave: true)
        }
    }
    
    
}
