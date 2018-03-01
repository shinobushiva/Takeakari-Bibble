//
//  Biblle.swift
//  TakeakariBibble
//
//  Created by Shinobu Izumi on 2017/11/08.
//  Copyright © 2017年 Shinobu Izumi. All rights reserved.
//

import Foundation
import CoreBluetooth

class DateUtils {
    class func dateFromString(string: String, format: String) -> Date {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: string)!
    }
    
    class func stringFromDate(date: Date, format: String) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

protocol BibbleDelegate {
    
    func onUpdated(rssi RSSI: NSNumber, for: Biblle) -> Void
}

class Biblle : NSObject, CBPeripheralDelegate{
    
    //    C0C00100-69FD-45AE-BCB9-6048ECEFDB8B の C0C00101-69FD-45AE-BCB9-6048ECEFDB8B
    
    static let BIBLLE_BUTTON_UUID = "C0C00101-69FD-45AE-BCB9-6048ECEFDB8B"
    
    static var characteristicProperty = [
        0x01 : "broadcast",
        0x02 : "read",
        0x04 : "write without response",
        0x08 : "write",
        0x10 : "notify",
        0x20 : "indicate",
        0x40 : "authenticated signed writes",
        0x80 : "extended properties",
        ]
    
    var peripheral : CBPeripheral
    var centralManager : CBCentralManager
    
    var data : AppleMfgData?
    
    var rssi: NSNumber = 0
    
    var timer: Timer!
    
    var delegate: BibbleDelegate?
    
    var buttonPressedAt : Date? = nil
    
    var buttonLongPressedAt : Date? = nil
    
    var isConnected = ""
    
    var connection : Connection
    
    var sw  = false
    
    func buttonPressed(valStr : String){
        
        print("Button pressed")
        if (valStr == "01") {
            self.buttonPressedAt =  Date()
            self.connection.sendRequest(msg: "{\"uuid\":\"\(self.peripheral.identifier.uuidString)\",\"button\": 1}\n")
        }
        
        if (valStr == "02") {
            self.buttonLongPressedAt = Date()
            self.connection.sendRequest(msg: "{\"uuid\":\"\(self.peripheral.identifier.uuidString)\",\"button\": 2}\n")
        }
        
    }
    
    init(forPeripheral: CBPeripheral, advertisementData: [String : Any], withCentralManager: CBCentralManager, rssi RSSI: NSNumber){
        
        self.centralManager = withCentralManager
        self.peripheral = forPeripheral
        self.data = nil
        self.connection = Connection.sharedManager
        super.init()
        
        self.peripheral.delegate = self
        
        print("--------------------")
        print("name: \(String(describing: self.peripheral.name))")
        print("UUID: \(self.peripheral.identifier.uuidString)")
        
        update(withAdvertisementData: advertisementData, rssi: RSSI)
    }
    
    func update(withAdvertisementData: [String : Any], rssi RSSI: NSNumber){
        print("advertisementData: \(withAdvertisementData)")
        
        print("RSSI: \(RSSI)")
        self.rssi = RSSI
        
        if(withAdvertisementData["kCBAdvDataIsConnectable"] != nil){
        }
        
        if(withAdvertisementData["kCBAdvDataAppleMfgData"] != nil){
        }
        
        if(withAdvertisementData["kCBAdvDataManufacturerData"] != nil){
            
            let manData = withAdvertisementData["kCBAdvDataManufacturerData"]! as! NSData
            self.data = AppleMfgData(data:manData)
            let distance = self.data!.distance(rssi:RSSI)
            let proximity = self.proximity(fromDistance: distance)
            
            print("distance, proximity = \(distance), \(proximity)")
            
        }
    }
    
    func proximity(fromDistance: Double) -> String{
        var proximity = "Unknown";
        if (fromDistance >= 2.0){ // 2m以上で　Far
            proximity = "Far";
        }else if(fromDistance >= 0.2){ //20cm以上で　Near
            proximity = "Near";
        }else if (fromDistance >= 0){ // 20cm未満で　Immediate
            proximity = "Immediate";
        }
        return proximity
    }
    
    func connect(){
//        self.centralManager.stopScan()
        
        print("connecting:\(self.peripheral)")
        self.centralManager.connect(self.peripheral, options: nil)
    }
    
    func connected(){
        print("connected!")
        self.isConnected = "(o)"
        self.peripheral.discoverServices(nil)
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    @objc func timerUpdate(tm: Timer) {
        self.peripheral.readRSSI()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.rssi = RSSI
        if(!self.isConnected.isEmpty) {
            self.connection.sendRequest(msg: "{\"uuid\":\"\(self.peripheral.identifier.uuidString)\",\"distance\":\(self.data!.distance(rssi: self.rssi))}\n")
        }
        self.delegate?.onUpdated(rssi: self.rssi, for: self)
    }
    
    func dataForCell() -> Dictionary<String, NSObject>{
        if (self.data == nil) {
            return [:]
        }
        
        let distance = self.data!.distance(rssi:self.rssi)
        let proximity = self.proximity(fromDistance: distance)
        
        let datePressStr = (self.buttonPressedAt != nil) ? DateUtils.stringFromDate(date: self.buttonPressedAt!, format: "HH:mm:ss") : ""
        
        let dateLongPressStr = (self.buttonLongPressedAt != nil) ? DateUtils.stringFromDate(date: self.buttonLongPressedAt!, format: "HH:mm:ss") : ""
        
        return [
            "Name": NSString(string: "\(self.isConnected)\(self.peripheral.name!)"),
            "UUID": NSString(string: self.peripheral.identifier.uuidString),
            "RSSI": self.rssi,
            "Distance": NSNumber(value: (distance*100).rounded()/100),
            "Approximate": NSString(string: proximity),
            "Button Pressed At": NSString(string: datePressStr),
            "Long Pressed At": NSString(string: dateLongPressStr)
        ]
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = peripheral.services!
        print("")
        print("Service discovered count=\(services.count)")
        
        for service in services {
            print("service=\(service)")
            //            if service.UUID.isEqual(self.serviceUUID) {
            //                self.peripheral.discoverCharacteristics(nil, forService:service)
            //            }
            peripheral.discoverCharacteristics(nil, for: service)
            
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristics = service.characteristics!
        print("")
        print("Characteristic discovered for sercie=\(service)")
        print("Characteristic discovered count=\(characteristics.count)")
        
        for characteristic in characteristics {
            let prop = characteristic.properties
            let i = Int(prop.rawValue)
            
            if(i == 0x02){
                peripheral.readValue(for: characteristic)
            }else if(i == 0x10){
                peripheral.setNotifyValue(true, for: characteristic)
            }else if(Biblle.characteristicProperty[i] != nil){
                print("\(Biblle.characteristicProperty[i]!)[\(i)]")
            }else{
                print("propertiy for \(i) is unknown")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.printValue(for: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        self.printValue(for: characteristic)
        
    }
    
    func printValue(for characteristic: CBCharacteristic){
        let prop = characteristic.properties
        let i = Int(prop.rawValue)
        let name = Biblle.characteristicProperty[i]!
        var hexStr = ""
        if let value = characteristic.value {
            hexStr = value.map {
                String(format: "%.2hhx", $0)
            }.joined()
            print("BIBBLE: \(hexStr)")
        }
        
        let uuid = characteristic.uuid
        if(Biblle.characteristicProperty[i] != nil){
            print("BIBBLE: \(uuid) - \(name)[\(i)] : \(hexStr)")
        }else{
            print("propertiy for \(i) is unknown")
        }
        
        if(characteristic.uuid.uuidString == Biblle.BIBLLE_BUTTON_UUID){
            
            if(characteristic.value != nil){
                self.buttonPressed(valStr: hexStr)
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let descriptors = characteristic.descriptors!
        print("")
        print("Descriptor discovered for characteristic=\(characteristic)")
        print("Descriptor discovered count=\(descriptors.count)")
        
        for descriptor in descriptors {
            print("descriptor=\(descriptor)")
        }
    }
    
}
