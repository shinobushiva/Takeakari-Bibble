//
//  ViewController.swift
//  TakeakariBibble
//
//  Created by Shinobu Izumi on 2017/11/02.
//  Copyright © 2017年 Shinobu Izumi. All rights reserved.
//

import Cocoa
import CoreBluetooth


class ViewController: NSViewController, CBCentralManagerDelegate, CBPeripheralDelegate,  NSTableViewDelegate, NSTableViewDataSource, BibbleDelegate {

    @IBOutlet weak var buttonConnect: NSButton!
    @IBOutlet weak var tableBiblles: NSTableView!
    
    var centralManager : CBCentralManager!
    
    var biblleMap : Dictionary<CBPeripheral, Biblle> = [:]
    
    var connection : Connection!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        self.connection = Connection.sharedManager
        self.connection.connect()
        
    }
    
    @IBAction func connect(_ sender: Any) {
        print("connect")
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        print(central.state.rawValue)
        
        switch (central.state) {
        case .poweredOff:
            print("BLE PoweredOff")
        case .poweredOn:
            print("BLE PoweredOn")
            // 2-1. Peripheral探索開始
            central.scanForPeripherals(withServices: nil, options: nil)
            /* ↑の第1引数はnilは非推奨。
             該当サービスのCBUUIDオブジェクトの配列が望ましい */
        case .resetting:
            print("BLE Resetting")
        case .unauthorized:
            print("BLE Unauthorized")
        case .unknown:
            print("BLE Unknown")
        case .unsupported:
            print("BLE Unsupported")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let _name = peripheral.name {
            print(_name)
            if(_name == "biblle"){
                
                if let val = biblleMap[peripheral] {
                    val.update(withAdvertisementData: advertisementData, rssi: RSSI)
                }else{
                    let biblle = Biblle(forPeripheral: peripheral, advertisementData: advertisementData, withCentralManager: centralManager, rssi: RSSI)
                    biblle.delegate = self
                    biblleMap[peripheral] = biblle
                }
                
                tableBiblles.reloadData()
            }
        }
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print(peripheral)
        
        biblleMap[peripheral]?.connected()
    }
    
    // ペリフェラルへの接続が失敗すると呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("failed...")
        print(peripheral)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return biblleMap.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        
        let key = Array(biblleMap.keys)[row]
        let data = biblleMap[key]?.dataForCell()
        
        cell.textField?.stringValue = "\(data![tableColumn!.title]!)"
//        cell.textLabel?.text = texts[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        print(tableColumn)
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = self.tableBiblles.selectedRow
        if ( row < 0 ) {
            return;
        }
        let key = Array(biblleMap.keys)[row]
        let data = biblleMap[key]!
        print(data.connect())
    }
    
    func onUpdated(rssi RSSI: NSNumber, for: Biblle) {
        tableBiblles.reloadData()
    }


    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

