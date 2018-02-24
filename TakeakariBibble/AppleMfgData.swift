//
//  AppleMfgData.swift
//  TakeakariBibble
//
//  Created by Shinobu Izumi on 2017/11/08.
//  Copyright © 2017年 Shinobu Izumi. All rights reserved.
//

import Foundation

class AppleMfgData : NSObject{
    var companyIdentifier : Int16 = 0
    var major: Int16 = 0
    var minor: Int16 = 0
    var measuredPower : Int8 = 0
    var dataType : Int8 = 0
    var dataLength : Int8 = 0
    var uuidString : String = ""
    
    init(data : NSData) {
        
        let companyIDRange = NSMakeRange(0,2);
        data.getBytes(&self.companyIdentifier, range: companyIDRange)
        if (self.companyIdentifier != 0x4C) {
            return
        }
        
        let dataTypeRange = NSMakeRange(2,1);
        data.getBytes(&self.dataType, range: dataTypeRange)
        if (self.dataType != 0x02) {
            return
        }
        
        let dataLengthRange = NSMakeRange(3,1);
        data.getBytes(&self.dataLength, range: dataLengthRange)
        if (self.dataLength != 0x15) {
            return
        }
        
        let uuidRange = NSMakeRange(4, 16)
        let majorRange = NSMakeRange(20, 2)
        let minorRange = NSMakeRange(22, 2)
        let powerRange = NSMakeRange(24, 1)
        
        var uuidBytes = Array<Int8>(repeating: 0, count: 17)
        data.getBytes(&uuidBytes, range: uuidRange)
        self.uuidString = (uuidBytes.map{String($0)}).joined(separator: "")
        
        data.getBytes(&self.major, range: majorRange)
        data.getBytes(&self.minor, range: minorRange)
        self.major = self.major.byteSwapped
        self.minor = self.minor.byteSwapped
        
        data.getBytes(&self.measuredPower, range: powerRange)
        
        print(self.companyIdentifier)
        print(self.dataType)
        print(self.dataLength)
        print(self.uuidString)
        print(self.major)
        print(self.minor)
        print(self.measuredPower)
        
    }
    
    func distance(rssi: NSNumber) -> Double {
        let _rssi = Double(truncating:rssi)
        let power = self.measuredPower
        var distance = -1.0;
        if(_rssi != 0){
            let ratio = _rssi * 1.0 / Double(power);
            if (ratio < 1.0) {
                distance = pow(ratio,10.0);
            }else {
                distance =  (0.89976) * pow(ratio, 7.7095) + 0.111;
            }
        }
        return distance
        
    }
}
