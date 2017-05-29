//
//  LocationManager.swift
//  awesomeCnCafe
//
//  Created by Song Zhou on 16/7/16.
//  Copyright © 2016年 Song Zhou. All rights reserved.
//

import Foundation
import MapKit

let currentCityDidChangeNotification = "currentCityDidChangedNotification"
let currentCityDidSupportNotification = "currentCityDidSupportNotification"
let currentCityNotSupportNotification = "currentCityNotSupportNotification"

let currentCityKey = "current city"

typealias LocationManagerCallback = (CLLocationManager, CLLocation) -> ()

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let sharedManager = LocationManager()
    
    fileprivate override init() { }
    
    /// callback approach rather than delegate
    var managers: [CLLocationManager: LocationManagerCallback] = [:]
    
    /// the last city visited when user exit app
    let lastCityCoordinate : CLLocationCoordinate2D? = {
        if let coordinateArray = Settings.sharedInstance[lastLocation] as? [Double], coordinateArray.count == 2 {
            let coordinate = CLLocationCoordinate2DMake(coordinateArray.first!, coordinateArray.last!)
            if CLLocationCoordinate2DIsValid(coordinate) {
                return coordinate
            }
            
        }
        
        return nil
    }()
    
    var supportCities = [String: City]()
    var requestedCities = [String: City]()
    
    let geoCoder = CLGeocoder()
    
    var currentCity: City? {
        didSet {
            if let city = currentCity {
                NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: currentCityDidChangeNotification), object: self, userInfo: [currentCityKey: city]))
                
                if  self.supportCities[city.pinyin] != nil {
                    NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: currentCityDidSupportNotification), object: self, userInfo: [currentCityKey: city]))
                } else {
                    NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: currentCityNotSupportNotification), object: self, userInfo: [currentCityKey: city]))
                }
            }
            
        }
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let callback = self.managers[manager] {
            if let location = locations.first {
                callback(manager, location)
            }
        }
    }
 
    // MARK: Public
    func updatingUserLocation(_ manager: CLLocationManager, completion: @escaping LocationManagerCallback) {
        if self.managers.count == 0 {
            manager.requestWhenInUseAuthorization()
        }
        
        self.managers[manager] = completion
        manager.delegate = LocationManager.sharedManager
        manager.startUpdatingLocation()
    }
    
    func getCurrentCity(withLocation location: CLLocation) {
        self.getCurrentCity(location, success: { [unowned self] (result) in
            if let city = result as? City {
                if let currentCity = self.currentCity {
                    if currentCity != city {
                        self.currentCity = city
                    }
                } else {
                    self.currentCity = city
                }
            }
            }, fail: { (error) in
                debugPrint("get current city with error: \(error.localizedDescription)")
            }
        )
        
    }
    

    // MARK: Private
    fileprivate func getCurrentCity(_ location: CLLocation, success: @escaping Success, fail: @escaping Fail) {
       self.reverseGeocodeLocation(location, success: { (result) in
            if let mark = result as? CLPlacemark {
                if let name = mark.name {
                    debugPrint("get reverse geo success: \(name)")
                } else {
                    debugPrint("get reverse geo success with getting name failed")
                }
                
                if let locality = mark.locality {
                    let cityMutableString = NSMutableString(string: locality)
                    CFStringTransform(cityMutableString, nil, kCFStringTransformToLatin, false)
                    CFStringTransform(cityMutableString, nil, kCFStringTransformStripDiacritics, false)
                    
                    var cityName = cityMutableString as String
                    cityName = cityName.replacingOccurrences(of: " ", with: "")
                    if cityName.hasSuffix("shi") {
                        cityName.removeSubrange(cityName.range(of: "shi")!)
                    }
                    
                    let city = City(pinyin: cityName)
                    city.location = mark.location
                    city.name = locality
                    success(city)
                }
                
            }
        }, fail: { (error) in
            fail(error)
        }, retry: 3)
    }
    
    fileprivate func reverseGeocodeLocation(_ location: CLLocation, success: @escaping Success, fail: @escaping Fail, retry: UInt) {
        self.geoCoder.reverseGeocodeLocation(location) {[unowned self] (placeMarks, error) in
            if let error = error {
                if retry != 0 {
                    debugPrint("get reverse geo code retry:\(retry), error: \(error.localizedDescription)")
                    self.reverseGeocodeLocation(location, success: success, fail: fail, retry: retry - 1)
                } else {
                    debugPrint("get reverse geo code fail, error: \(error.localizedDescription)")
                    fail(error as NSError)
                }
            } else {
                if let mark = placeMarks?.first {
                    debugPrint("get reverse geo code success:\(mark.name!)")
                   success(mark)
                }
            }
        }
    }
    
    
}
