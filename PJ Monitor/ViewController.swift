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
    @IBOutlet weak var batteryVoltageLabel: UILabel!
    @IBOutlet weak var batteryConditionLabel: UILabel!
    @IBOutlet weak var batteryConditionImage: UIImageView!
    @IBOutlet weak var lightLeftButton: UIButton!
    @IBOutlet weak var lightRightButton: UIButton!
    @IBOutlet weak var lightLeftSlider: UISlider!
    @IBOutlet weak var lightRightSlider: UISlider!
    
    let generator = UINotificationFeedbackGenerator()
    
    var centralManager: CBCentralManager!
    
    var pjControlPeripheral: CBPeripheral!
    
    let batteryServiceCBUUID = CBUUID(string: "9f832063-bbe1-45b2-b9cb-b4c7b2a0c36a")
    let batteryLevelCharacteristicCBUUID = CBUUID(string: "cd3d8382-99b8-434e-b221-74d18e68df9a")
    let batteryVoltageCharacteristicCBUUID = CBUUID(string: "d5e05399-8d79-40bd-afaf-db7b63eb6035")
    
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
        lightLeftSlider.isEnabled = false
        lightLeftButton.isEnabled = false
        lightLeftCurrentLevel.isEnabled = false
        
        lightRightIndicator.startAnimating()
        lightRightIndicator.hidesWhenStopped = true
        
        batteryVoltageLabel.text = "--"
        batteryVoltageLabel.isEnabled = false
        batteryConditionLabel.text = "--"
        batteryConditionLabel.isEnabled =  false
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
    
    func setBatteryConditionLabel(_ batteryVoltage: Double) {
        if batteryVoltage > 11.5 {
            batteryConditionLabel.text = "Super".uppercased()
            batteryConditionImage.image = UIImage(systemName: "checkmark.circle.fill")
            batteryConditionImage.tintColor = UIColor(named: "Color-4")
            return
        }
        if batteryVoltage <= 11.0 {
            batteryConditionLabel.text = "Achtung".uppercased()
            batteryConditionImage.image = UIImage(systemName: "exclamationmark.triangle.fill")
            batteryConditionImage.tintColor = UIColor(named: "Color-8")
            return
        }
        if batteryVoltage <= 11.5 {
            batteryConditionLabel.text = "Ok".uppercased()
            batteryConditionImage.image = UIImage(systemName: "exclamationmark.circle.fill")
            batteryConditionImage.tintColor = UIColor(named: "Color-7")
            return
        }

    }
    
    func setBatteryLevelLabel(_ batteryVoltage: Double) {
        batteryVoltageLabel.text = String(format: "%.1f V", batteryVoltage)
    }
    
    func setBatteryLevelInvalid() {
        batteryVoltageLabel.text = "--"
    }
    
    func isBatteryLevelValid(_ batteryLevel: Int) -> Bool {
        return batteryLevel != -1
    }
    
    func onBatteryVoltageReceived(_ batteryVoltageRaw: Int) {
        
        if !isBatteryLevelValid(batteryVoltageRaw) {
            setBatteryLevelInvalid()
            return
        }
        
        batteryVoltageLabel.isEnabled = true
        batteryConditionLabel.isEnabled =  true
        
        let batteryVoltage: Double = Double(batteryVoltageRaw)*0.1
        
        setBatteryConditionLabel(batteryVoltage)
        setBatteryLevelLabel(batteryVoltage)
        batteryIndicator.stopAnimating()
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
            lightLeftSlider.value = 0
            return
        }
        
        if(currentDimmLevel) == 0 {
            writeLightLeftDimmLevel(100)
            generator.notificationOccurred(.success)
            lightLeftSlider.value = 1
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
        lightLeftSlider.isEnabled = false
        lightLeftButton.isEnabled = false
        lightLeftCurrentLevel.isEnabled = false
        
        batteryVoltageLabel.text = "--"
        batteryVoltageLabel.isEnabled = false
        batteryConditionLabel.text = "--"
        batteryConditionLabel.isEnabled =  false
        batteryIndicator.startAnimating()
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            print(service)
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
                    lightLeftSlider.isEnabled = true
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
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case batteryLevelCharacteristicCBUUID:
            break
        case batteryVoltageCharacteristicCBUUID:
            let batteryLevel = getIntFromCharacteristic(from: characteristic)
            onBatteryVoltageReceived(batteryLevel)
            break
        case leftLightDimmCharacteristicCBUUID:
            let dimmLevel = getIntFromCharacteristic(from: characteristic)
            onLedDimmLevelReceived(dimmLevel)
            break
        default:
            break
        }
    }
    
    private func getIntFromCharacteristic(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value, let batteryLevelValue = characteristicData.first else { return -1 }
        
        return Int(batteryLevelValue)
    }
}

