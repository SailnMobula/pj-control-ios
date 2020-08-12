//
//  ViewController.swift
//  PJ Monitor
//
//  Created by Kramer, Julian on 05.06.20.
//  Copyright © 2020 Julian Kramer. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    @IBOutlet weak var lightLeftView: UIView!
    @IBOutlet weak var lightRightView: UIView!
    @IBOutlet weak var batteryView: UIView!
    @IBOutlet weak var lightLeftCurrentLevel: UILabel!
    @IBOutlet weak var lightRightCurrentLevel: UILabel!
    @IBOutlet weak var lightLeftIndicator: UIActivityIndicatorView!
    @IBOutlet weak var lightRightIndicator: UIActivityIndicatorView!
    @IBOutlet weak var batteryIndicator: UIActivityIndicatorView!
    @IBOutlet weak var batteryCurrentLevelLabel: UILabel!
    @IBOutlet weak var lightLeftButton: UIButton!
    @IBOutlet weak var lightRightButton: UIButton!
    @IBOutlet weak var lightLeftSlide: UISlider!
    @IBOutlet weak var lightRightSlider: UISlider!
    
    let generator = UINotificationFeedbackGenerator()
    
    var centralManager: CBCentralManager!
    
    var pjControlPeripheral: CBPeripheral!
    
    let batteryServiceCBUUID = CBUUID(string: "180F")
    let batteryLevelCharacteristicCBUUID = CBUUID(string: "2A19")
    
    let ibsServiceCBUUID = CBUUID(string: "180F")
    let ibsSocCharacteristicCBUUID = CBUUID(string: "2A19")
    let ibsSohCharacteristicCBUUID = CBUUID(string: "2A19")
    let ibsVoltageCharacteristicCBUUID = CBUUID(string: "2A19")
    let ibsTemperatureCharacteristicCBUUID = CBUUID(string: "2A19")
    
    let leftLightServiceCBUUID = CBUUID(string: "98194a8e-a697-4b49-93f5-25ca2602013c")
    let leftLightDimmCharacteristicCBUUID = CBUUID(string: "4d5c48e8-509c-4f61-a39d-ccb8f78dee34")
    
    var ledDimmCharacteristic: CBCharacteristic?
    
    var currentDimmLevel: UInt8 = 0
    var allowTX = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        lightLeftIndicator.startAnimating()
        lightLeftIndicator.hidesWhenStopped = true
        lightLeftSlide.isEnabled = false
        lightLeftButton.isEnabled = false
        lightLeftCurrentLevel.isEnabled = false
        
        lightRightIndicator.startAnimating()
        lightRightIndicator.hidesWhenStopped = true
        
        batteryIndicator.startAnimating()
        batteryIndicator.hidesWhenStopped = true
        
        let cornerRadius: CGFloat = 16
        lightLeftView.layer.cornerRadius = cornerRadius
        lightRightView.layer.cornerRadius = cornerRadius
        batteryView.layer.cornerRadius = cornerRadius
        
        //TODO Deactivate if ble service is implemented
        lightRightIndicator.stopAnimating()
        lightRightSlider.isEnabled = false
        lightRightButton.isEnabled = false
        lightRightCurrentLevel.isEnabled = false
    }
    
    func onBatteryLevelReceived(_ batteryLevel: Int) {
        
        if(batteryLevel == -1) {
            batteryCurrentLevelLabel.text = "--"
            return
        }
        
        batteryIndicator.stopAnimating()
        batteryCurrentLevelLabel.text = "\(batteryLevel) %"
    }
    
    func onLedDimmLevelReceived(_ dimmLevel: Int) {
        if(dimmLevel == -1) {
            lightLeftCurrentLevel.text = "--"
            return
        }
        
        currentDimmLevel = UInt8(dimmLevel)
        
        if(dimmLevel == 0) {
            lightLeftCurrentLevel.text = "Aus".uppercased()
            lightLeftButton.setBackgroundImage(UIImage(systemName: "lightbulb"), for: .normal)
            return
        }
        lightLeftButton.setBackgroundImage(UIImage(systemName: "lightbulb.fill"), for: .normal)
        lightLeftCurrentLevel.text = "\(dimmLevel) %"
    }
    
    func setDimmLevel(_ dimmLevel: UInt8) {
        if !isDelayForSliderExpired()   {return}
        
        if dimmLevel == currentDimmLevel    {return}
        
        writeLightLeftDimmLevel(dimmLevel)
        activateDelayForSlider()
    }
    
    func activateDelayForSlider() {
        allowTX = false
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { timer in
            self.allowTX = true
        }
    }
    
    func isDelayForSliderExpired() -> Bool {
        return allowTX
    }
    
    func writeLightLeftDimmLevel(_ dimmLevel: UInt8) {
        guard let dimmCharacteristic = ledDimmCharacteristic else {
            return
        }
        
        let convertedValue = Data(_ : [dimmLevel])
        if dimmCharacteristic.properties.contains(.write) {
            pjControlPeripheral.writeValue(convertedValue, for: dimmCharacteristic, type: CBCharacteristicWriteType.withResponse)
            return
        }
        
        if dimmCharacteristic.properties.contains(.writeWithoutResponse) {
            pjControlPeripheral.writeValue(convertedValue, for: dimmCharacteristic, type: CBCharacteristicWriteType.withoutResponse)
            return
        }
    }
    
    func onError(_ error: Error) {
        print(error)
    }
    
    @IBAction func onLightLeftLevelChange(_ sender: UISlider) {
        let dimmLevel = UInt8(sender.value*100)
        setDimmLevel(dimmLevel)
    }
    
    @IBAction func onLightLeftButton(_ sender: UIButton) {
        if(currentDimmLevel) > 0 {
            writeLightLeftDimmLevel(0)
            generator.notificationOccurred(.success)
            lightLeftSlide.value = 0
            return
        }
        
        if(currentDimmLevel) == 0 {
            writeLightLeftDimmLevel(100)
            generator.notificationOccurred(.success)
            lightLeftSlide.value = 1
            return
        }
    }
    
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [leftLightServiceCBUUID, batteryServiceCBUUID])
        @unknown default:
            print("central.state is .unknown")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        pjControlPeripheral = peripheral
        pjControlPeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(pjControlPeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        pjControlPeripheral.discoverServices([leftLightServiceCBUUID, batteryServiceCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        centralManager.scanForPeripherals(withServices: [leftLightServiceCBUUID, batteryServiceCBUUID])
        lightLeftIndicator.startAnimating()
        lightLeftSlide.isEnabled = false
        lightLeftButton.isEnabled = false
        lightLeftCurrentLevel.isEnabled = false
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            print(service)
            print(service.characteristics ?? "chars are nil")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == leftLightDimmCharacteristicCBUUID {
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.properties.contains(.write) {
                    ledDimmCharacteristic = characteristic
                    lightLeftIndicator.stopAnimating()
                    lightLeftSlide.isEnabled = true
                    lightLeftButton.isEnabled = true
                    lightLeftCurrentLevel.isEnabled = true
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            onError(err)
            return
        }
        
        switch characteristic.uuid {
        case leftLightDimmCharacteristicCBUUID:
            let dimmLevel = getIntFromCharacteristic(from: characteristic)
            onLedDimmLevelReceived(dimmLevel)
            break
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case batteryLevelCharacteristicCBUUID:
            let batteryLevel = getIntFromCharacteristic(from: characteristic)
            onBatteryLevelReceived(batteryLevel)
            break
        case leftLightDimmCharacteristicCBUUID:
            let dimmLevel = getIntFromCharacteristic(from: characteristic)
            onLedDimmLevelReceived(dimmLevel)
            break
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
            break
        }
    }
    
    private func getIntFromCharacteristic(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value, let batteryLevelValue = characteristicData.first else { return -1 }
        
        return Int(batteryLevelValue)
    }
}

