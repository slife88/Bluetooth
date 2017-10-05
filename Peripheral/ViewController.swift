//
//  ViewController.swift
//  Peripheral
//
//  Created by RTC01 on 2017/10/5.
//  Copyright © 2017年 JasonHuang. All rights reserved.
//

import UIKit
import CoreBluetooth

enum SendDataError: Error {
    case CharacteristicNotFound
}

class ViewController: UIViewController, CBPeripheralManagerDelegate {

    let UUID_SERVICE = "A001"
    let UUID_CHARACTERISTIC = "C001"
    var peripheralManager: CBPeripheralManager!
    // 記錄所有的 characteristic
    var charDictionary = [String: CBMutableCharacteristic]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let queue = DispatchQueue.global()
        // 將觸發1號method
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }

    /* 1號method */
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // 先判斷藍牙是否開啟，如果不是藍牙4.x ，也會傳回電源未開啟
        guard peripheral.state == .poweredOn else {
            // iOS 會出現對話框提醒使用者
            return
        }
        var service: CBMutableService
        var characteristic: CBMutableCharacteristic
        var charArray = [CBCharacteristic]()
        
        // 設定第一個 service A001
        service = CBMutableService(type: CBUUID(string: UUID_SERVICE), primary: true)
        // 設定第一個 characteristic C001
        characteristic = CBMutableCharacteristic(
            type: CBUUID(string: UUID_CHARACTERISTIC),
            properties: [.notifyEncryptionRequired, .writeWithoutResponse],
            value: nil,
            permissions: [.writeEncryptionRequired]
        )
        charArray.append(characteristic)
        charDictionary[UUID_CHARACTERISTIC] = characteristic
        service.characteristics = charArray
        // 準備觸發２號 method
        peripheralManager.add(service)
    }
    
    /* 2號method*/
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            print("ERROR:{\(#file, #function)}\n")
            print(error!.localizedDescription)
            return
        }
        
        // 設定行動裝置的名稱
        let deviceName = "某某某的 mac os"
        // 開始廣播 讓central端可以找到這台裝置，觸發3號method
        peripheral.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [service.uuid],
             CBAdvertisementDataLocalNameKey: deviceName]
        )
    }
    
    /* 3號method*/
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        //週邊裝置開始廣播
        //以下是自動函數
        print("開始廣播")
    }
    
    /* 收到 central 端的訂閱指令 */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic){
        //central端 掃描到 peripheral 配對連線之後, 如果有訂閱, phripheral就停止廣播，讓其他central端 掃瞄不到 無法配對連線，才不會多個central都一起收到peripheral的廣播資料
        if peripheral.isAdvertising {
            peripheral.stopAdvertising()
            print("停止廣播")
        }
        if characteristic.uuid.uuidString == UUID_CHARACTERISTIC {
            print("\(UUID_CHARACTERISTIC) 被訂閱")
        }
    }
    
    /* 收到 central 端 取消訂閱指令 */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid.uuidString == UUID_CHARACTERISTIC {
            print("\(UUID_CHARACTERISTIC) 取消訂閱")
        }

    }
    
    /* 自定義函數 送資料到 central 端 */
    func sendData(_ data: Data, uuidString: String) throws {
        //確定UUID資料  存在前面準備好的characteristic字典裡面
        guard let characteristic = charDictionary[uuidString] else {
            throw SendDataError.CharacteristicNotFound
        }
        //藍芽過程中 傳輸的資料都要轉成data格式
        peripheralManager.updateValue(
            data,
            //data要透過哪個characteristic傳送 這裡是C001
            for: characteristic,
            //送給哪些有訂閱的 central端, nil:所有有訂閱的都送, 可以指定要傳給哪幾個
            onSubscribedCentrals: nil
        )
    }
    
    // 讀取 從 Center 端 write 傳過來的資料 data格式
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let at = requests.first else {
            return
        }
        guard let data = at.value else {
            return
        }
        //如果收到資料 需要回應(成功收到了) 這個範例前面設定不需要 response
        //peripheral.respond(to: at, withResult: .success)
        //把聊天的資料 顯示在畫面上
        DispatchQueue.main.async {
            var string = String(data: data, encoding: .utf8)!
            string = "裝置端: " + string
            print(string)
            //如果 textView.text 是 nil 預設給空字串(.text 是 String?), 如果是空字串的話
            if self.textView.text ?? "" == "" {
                self.textView.text = string
            } else {
                self.textView.text = self.textView.text! + "\n" + string
              //self.text.View.string = string //在 mac 上是 .string, ios 是 .text
            }
            print("received: \(string)")
        }
    }
    
    //等Center端主動要求資料，才回傳Center端所要求的資料，比如 central端 想要知道電量/時間
    /*這次是要做聊天室 還不需要這個函數
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid.uuidString == "C003"{
            let string = Date().description(with: Locale.current)//目前時間
            let data = string.data(using: .utf8)
            print(string)
            request.value = data
        }
    }
    */
    @IBOutlet weak var textView: UITextView! //mac os 上是 NSTextView
    @IBOutlet weak var textField: UITextField! //mac os 上是 NSTextField
    //按鈕按下之後，將textField的聊天內容送出去
    @IBAction func sendClick(_ sender: Any) {
        let string = textField.text!
        if self.textView.text ?? "" == "" {
            self.textView.text = string
        } else {
            self.textView.text = self.textView.text! + "\n" + string
        }
        //把本地端的聊天內容 用 C001 這個 characteristic，送去Central
        //sendData 有 throws ，所以呼叫時要用 do catch 強制 try
        do {
            try sendData(string.data(using: .utf8)!, uuidString: UUID_CHARACTERISTIC)
            
        } catch {
            print(error)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

