import Foundation
import IOBluetooth

guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice],
      let buds = devices.first(where: { ($0.nameOrAddress ?? "").contains("realme Buds") }) else {
    exit(1)
}

class RFDelegate: NSObject, IOBluetoothRFCOMMChannelDelegate {
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        print("rfcommChannelOpenComplete! status: \(error) (kIOReturnSuccess = \(kIOReturnSuccess))")
        if error == kIOReturnSuccess {
            print("Channel opened successfully! Channel ID: \(rfcommChannel.getID()), MTU: \(rfcommChannel.getMTU())")
            print("Closing channel now...")
            rfcommChannel.close()
        } else {
            print("Failed to open channel: \(error)")
        }
        CFRunLoopStop(CFRunLoopGetMain())
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        print("rfcommChannelClosed!")
        CFRunLoopStop(CFRunLoopGetMain())
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        print("rfcommChannelData received: \(dataLength) bytes")
    }
}

let delegate = RFDelegate()
var channel: IOBluetoothRFCOMMChannel?
print("Opening RFCOMM Channel 15 asynchronously...")
let ret = buds.openRFCOMMChannelAsync(&channel, withChannelID: 15, delegate: delegate)
print("openRFCOMMChannelAsync returned: \(ret)")

CFRunLoopRun()
print("Exiting RFCOMM test.")
