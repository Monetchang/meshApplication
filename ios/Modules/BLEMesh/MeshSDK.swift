//
//  MeshSDK.swift
//  nRFSingleTon
//
//  Created by wuzhengbin on 2019/12/19.
//  Copyright © 2019 wuzhengbin. All rights reserved.
//

import Foundation
import os.log
import nRFMeshProvision
import CoreBluetooth

enum DeviceConfigurationPhase {
    case provisoning
    case identifying
    case none
}

struct RuntimeVendorMessage: VendorMessage {
    let opCode: UInt32
    let parameters: Data?
    
    var isSegmented: Bool = false
    var security: MeshMessageSecurity = .low
    
    init(opCode: UInt8, for model: Model, parameters: Data?) {
        self.opCode = (UInt32(0xC0 | opCode) << 16) | UInt32(model.companyIdentifier!.bigEndian)
        self.parameters = parameters
    }
    
    init?(parameters: Data) {
        // This init will never be used, as it's used for incoming messages.
        return nil
    }
}

extension RuntimeVendorMessage: CustomDebugStringConvertible {

    var debugDescription: String {
        let hexOpCode = String(format: "%2X", opCode)
        return "RuntimeVendorMessage(opCode: \(hexOpCode), parameters: \(parameters!.hex), isSegmented: \(isSegmented), security: \(security))"
    }
    
}

@objcMembers
open class MeshSDK: NSObject {
    public static let sharedInstance = MeshSDK()
    
    var meshNetworkManager: MeshNetworkManager!
    var connection: NetworkConnection!
    var centralManager: CBCentralManager!
    var currentNetworkKey: String!
    var currentApplicationKey: String!
    
    var phase: DeviceConfigurationPhase!
    
    var discoveredPeripherals = [(device: UnprovisionedDevice, peripheral: CBPeripheral, rssi: Int)]()
    var disposedDiscoveredDevices = [(identifier: String, rssi: Int, name: String)]()
    var disposedDiscoveredReadableDevices = [[String: Any]]()
    var provisioningManager: ProvisioningManager!
    var capabilitiesReceived = false
    var unprovisionedDevice: UnprovisionedDevice!
    var bearer: ProvisioningBearer!
    var currentNode: Node!
    
    private var provisioningNetworkKey: String!
    private var publicKey: PublicKey?
    private var authenticationMethod: AuthenticationMethod?
    
    typealias CheckPermissionCallback = (String, Bool) -> ()
    typealias ScanResultCallback = ([(device: UnprovisionedDevice, peripheral: CBPeripheral, rssi: Int)]) -> ()
    
    typealias DisposedScanResultCallback = ([(identifier: String, rssi: Int, name: String)]) -> ()
    typealias DisposedScanResultReadableCallback = ([[String: Any]]) -> ()
    typealias LocalProvisionedResultCallback = ([Node]) -> () // 暂定
    typealias LocalProvisionedDevicesCallback = ([[String: Any]]) -> ()
    typealias GenericOnOffStatusCallback = (Bool) -> ()
    typealias LightPropertyStatusCallback = (Bool) -> ()
    typealias ProvisioningStatusCallback = ([String: Int]) -> ()
    typealias BindApplicationKeyForNodeCallback = ([String: Int]) -> ()
    typealias BindApplicationKeyForBaseModelCallback = ([String: Int]) -> ()
    typealias BindApplicationKeyForCustomModelCallback = ([String: Int]) -> ()
    typealias ResetNodeCallback = (Bool) -> ()
    typealias MeshMessageSendCallback = (Bool) -> ()
    typealias QuadruplesResultCallback = ([String: Any]) -> ()
    
    var lightPropertyStatusCallback: LightPropertyStatusCallback!
    var resetNodeCallback: ResetNodeCallback!
    var quadruplesResultCallback: QuadruplesResultCallback!
    var checkPermissionCallBack: CheckPermissionCallback!
    var localProvisionedDevicesCallback: LocalProvisionedDevicesCallback!
    var scanResultCallback: ScanResultCallback!
    var disposedScanResultCallback: DisposedScanResultCallback!
    var disposedScanResultReadableCallback: DisposedScanResultReadableCallback!
    var localProvisionedResultCallback: LocalProvisionedResultCallback!
    var genericOnOffStatusCallback: GenericOnOffStatusCallback!
    var provisioningStatusCallback: ProvisioningStatusCallback!
    var bindApplicationKeyForNodeCallback: BindApplicationKeyForNodeCallback!
    var bindApplicationKeyForBaseModelCallback: BindApplicationKeyForBaseModelCallback!
    var bindApplicationKeyForCustomModelCallback: BindApplicationKeyForCustomModelCallback!
    var meshMessageSendCallback: MeshMessageSendCallback!
    
    public func setup() {
        meshNetworkManager = MeshNetworkManager()
        meshNetworkManager.acknowledgmentTimerInterval = 0.600
        meshNetworkManager.transmissionTimerInteral = 0.600
        meshNetworkManager.retransmissionLimit = 2
        meshNetworkManager.acknowledgmentMessageInterval = 5.0
        // As the interval has been increased, the timeout can be adjusted.
        // The acknowledged message will be repeated after 5 seconds,
        // 15 seconds (5 + 5 * 2), and 35 seconds (5 + 5 * 2 + 5 * 4).
        meshNetworkManager.acknowledgmentMessageTimeout = 40.0
        meshNetworkManager.logger = self
        
        // Try loading the saved configuration
        var loaded = false
        do {
            loaded = try meshNetworkManager.load()
        } catch {
            print(error)
        }
        
        if !loaded {
            createNewMeshNetwork()
        } else {
            meshNetworkDidChange()
        }
        
        // 初始化 CentralManager
        centralManager = CBCentralManager()
    }
    
    private func createNewMeshNetwork() {
        let provisioner = Provisioner(name: UIDevice.current.name,
                                      allocatedUnicastRange: [AddressRange(0x0001...0x199A)],
                                      allocatedGroupRange:   [AddressRange(0xC000...0xCC9A)],
                                      allocatedSceneRange:   [SceneRange(0x0001...0x3333)])
        _ = meshNetworkManager.createNewMeshNetwork(withName: "nRF Mesh Network", by: provisioner)
        _ = meshNetworkManager.save()
        
        meshNetworkDidChange()
    }
    
    private func meshNetworkDidChange() {
        connection?.close()
        
        let meshNetwork = meshNetworkManager.meshNetwork!
        
        // Set up local Elements on the phone.
        let element0 = Element(name: "Primary Element", location: .first, models: [
            Model(sigModelId: 0x1000, delegate: GenericOnOffServerDelegate()),
            Model(sigModelId: 0x1002, delegate: GenericLevelServerDelegate()),
            Model(sigModelId: 0x1001, delegate: GenericOnOffClientDelegate()),
            Model(sigModelId: 0x1003, delegate: GenericLevelClientDelegate())
        ])
        let element1 = Element(name: "Secondary Element", location: .second, models: [
            Model(sigModelId: 0x1000, delegate: GenericOnOffServerDelegate()),
            Model(sigModelId: 0x1002, delegate: GenericLevelServerDelegate()),
            Model(sigModelId: 0x1001, delegate: GenericOnOffClientDelegate()),
            Model(sigModelId: 0x1003, delegate: GenericLevelClientDelegate())
        ])
        meshNetworkManager.localElements = [element0, element1]
        
        connection = NetworkConnection(to: meshNetwork)
        connection!.dataDelegate = meshNetworkManager
        connection!.logger = self
        meshNetworkManager.transmitter = connection
        connection!.open()
        
        //
        
    }
    

}

// MARK: - Network Key Components
extension MeshSDK {
    public func getAllNetworkKeys() -> [String] {
        let networkKeys = meshNetworkManager.meshNetwork!.networkKeys
        return networkKeys.map { $0.key.hex }
        // 简化版本
//        return networkKeys.map { networkKey in
//            return networkKey.key.hex
//        }
        // 原始版本
//        var stringKeys:[String] = []
//        for nw in networkKeys {
//            stringKeys.append(nw.key.hex)
//        }
//        return stringKeys
    }
    
    public func createNetworkKey(key: String) {
        guard let data = Data(hex: key) else { return }
        let network = meshNetworkManager.meshNetwork!
        let index = network.networkKeys.count

        _ = try! network.add(networkKey: data, name: "NetworkKey \(index)")
        if meshNetworkManager.save() {
            print("添加 key 成功")
        } else {
            
        }
    }
    
    public func deleteNetworkKey(key: String) {
        let networkKeys = meshNetworkManager.meshNetwork!.networkKeys
        let network = meshNetworkManager.meshNetwork!
        var deleteKey: NetworkKey
        for nw in networkKeys {
            if nw.key.hex == key {
                deleteKey = nw
                _ = try! network.remove(networkKey: deleteKey)
                if meshNetworkManager.save() {
                    
                } else {
                    
                }
            }
        }
    }
    
    public func setCurrentNetworkKey(key: String) {
        for nk in meshNetworkManager.meshNetwork!.networkKeys {
            if nk.key.hex == key {
                currentNetworkKey = nk.key.hex
            }
            UserDefaults.standard.set(key, forKey: "mesh_currentNetworkKey")
            UserDefaults.standard.synchronize()
        }
    }
    
    public func getCurrentNetworkKey() -> String {
        return UserDefaults.standard.string(forKey: "mesh_currentNetworkKey") ?? ""
    }
}

// MARK: - Application Key
extension MeshSDK {
    public func setCurrentApplicationKey(key: String, networkKey: String) {
        for nk in meshNetworkManager.meshNetwork!.networkKeys {
            if nk.key.hex == networkKey {
                UserDefaults.standard.set(key, forKey: "mesh_currentAppKey")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    public func getCurrentApplicationKey() -> String {
        return UserDefaults.standard.string(forKey: "mesh_currentApplicationKey") ?? ""
    }
    
    public func createApplicationKey(networkKey: String) {
        let applicationKeyData = Data.random128BitKey()
        let networkKeys = meshNetworkManager.meshNetwork!.networkKeys
        let network = meshNetworkManager.meshNetwork!
        
        let applicationKeyCount = network.applicationKeys.count
        let applicationKey = try! network.add(applicationKey: applicationKeyData, name: String("App Key \(applicationKeyCount+1)"))
        var boundToNetworkKey: NetworkKey
        for nw in networkKeys {
            if nw.key.hex == networkKey {
                boundToNetworkKey = nw
                try? applicationKey.bind(to: boundToNetworkKey)
            }
        }
        if meshNetworkManager.save() {
            print("这回总该有 application key 了吧")
        } else {
            
        }
    }
    
    public func getAllApplicationKey(networkKey: String) -> [String] {
        let applicationKeys = meshNetworkManager.meshNetwork?.applicationKeys
        let networkKeys = meshNetworkManager.meshNetwork?.networkKeys
        guard let boundedNetworkKey = networkKeys?.first(where: { (item) -> Bool in
            return item.key.hex == networkKey
        }) else { return [] }
        let applicationKeysInNetwork = (applicationKeys?.filter({ (item) -> Bool in
            return item.isBound(to: boundedNetworkKey)
        }))!
        var keys:[String] = []
        for applicationKey in applicationKeysInNetwork {
            keys.append(applicationKey.key.hex)
        }
        return keys
    }
    
    public func removeApplicationKey(appKey: String, networkKey: String) {
        let network = meshNetworkManager.meshNetwork!
        var toDeleteAppKey: ApplicationKey
        for ak in network.applicationKeys {
            if ak.key.hex == appKey {
                toDeleteAppKey = ak
                // 进行删除操作
                if toDeleteAppKey.isUsed(in: network) {
                    return
                } else {
                    try? network.remove(applicationKey: toDeleteAppKey)
                    if !meshNetworkManager.save() {
                        // 删除失败
                    }
                }
            }
        }
    }
}

// MARK: - Load Local Provisioned Node
extension MeshSDK {
     func getProvisionedDevices(callback: @escaping LocalProvisionedResultCallback) {
        self.localProvisionedResultCallback = callback
        let network = meshNetworkManager.meshNetwork!
        let unConfiguredNodes = network.nodes.filter({ !$0.isConfigComplete && !$0.isProvisioner })
        self.localProvisionedResultCallback(unConfiguredNodes)
    }
    
    
     func getProvisionedNodes(callback: @escaping LocalProvisionedDevicesCallback) {
        localProvisionedDevicesCallback = callback
        let network = meshNetworkManager.meshNetwork!
        let unConfiguredNodes = network.nodes.filter({ !$0.isConfigComplete && !$0.isProvisioner })
        var devices = [[String: Any]]()
        
        var elementArray = [[String: Any]]()
        unConfiguredNodes.forEach { node in
            
            node.elements.forEach { element in
                
                var elementDict = [String: Any]()
                elementDict["elementAddress"] = element.unicastAddress.asString()
                var models = [[String: Any]]()
                element.models.forEach({ model in
                    let modelDict = ["modelId": model.modelIdentifier.asString()]
                    models.append(modelDict)
                })
                elementDict["models"] = models
                elementArray.append(elementDict)
            }
            
            
            let device = ["name": node.name ?? "Unknown Device",
                          "uuid": node.uuid.uuidString,
                          "elements": elementArray] as [String : Any]
            devices.append(device as [String : Any])
        }
        localProvisionedDevicesCallback(devices)
    }
    
    public func getCompositionData(uuid: String) {
        let message = ConfigCompositionDataGet()
        meshNetworkManager.delegate = self
        let network = meshNetworkManager.meshNetwork!
//        guard let node = network.nodes.first(where: { $0.uuid.uuidString == uuid } ) else {
//            return
//        }
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            _ = try? meshNetworkManager.send(message, to: currentNode)
        }
        
    }
    
    public func getTtl(uuid: String) {
        let message = ConfigDefaultTtlGet()
        let network = meshNetworkManager.meshNetwork!
//        guard let node = network.nodes.first(where: { $0.uuid.uuidString == uuid } ) else {
//            return
//        }
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            _ = try? meshNetworkManager.send(message, to: node)
        }
    }
}

// MARK: - 对设备发送控制指令
extension MeshSDK {
     func getQuadruples(uuid: String, callback: @escaping QuadruplesResultCallback) {
        meshNetworkManager.delegate = self
        quadruplesResultCallback = callback
        
        let network = meshNetworkManager.meshNetwork!
//        guard let node = network.nodes.first(where: { $0.uuid.uuidString == uuid } ) else {
//            return
//        }
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            
            if let opCode = UInt8("00", radix: 16) {
                let parameters = Data(hex: "")
//                let model: Model = node.elements[0].models.first(where: { $0.name == "Vendor Model" && $0.modelIdentifier == 1} )!
                for model in node.elements[0].models where model.name == "Vendor Model" && model.modelIdentifier == 1 {
                    let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
                    _ = try? meshNetworkManager.send(message, to: model)
                }
            }
        }
    }
    
     func setGenericOnOff(uuid: String, isOn: Bool, callback: @escaping GenericOnOffStatusCallback) {
        meshNetworkManager.delegate = self
        genericOnOffStatusCallback = callback
        let message = GenericOnOffSet(isOn)
        let network = meshNetworkManager.meshNetwork!
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            for model in node.elements[0].models where model.name == "Generic OnOff Server" {
                _ = try? meshNetworkManager.send(message, to: model)

            }

        }
    }
    
     func setLightProperties(uuid: String, c: Int, w: Int, r: Int, g: Int, b: Int, callback: @escaping LightPropertyStatusCallback) {
        meshNetworkManager.delegate = self
        self.lightPropertyStatusCallback = callback
        if let opCode = UInt8("05", radix: 16) {
            let cHex = String(format: "%02X", c)
            let wHex = String(format: "%02X", w)
            let rHex = String(format: "%02X", r)
            let gHex = String(format: "%02X", g)
            let bHex = String(format: "%02X", b)
            
            let network = meshNetworkManager.meshNetwork!
            for node in network.nodes where node.uuid.uuidString == uuid {
                currentNode = node
                let parameters = Data(hex: cHex+wHex+rHex+gHex+bHex)
                for model in node.elements[0].models where (model.name == "Vendor Model" && model.modelIdentifier == 1) {
                    let message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
                    _ = try? meshNetworkManager.send(message, to: model)

                }
            }
        }
    }
    
     func sendMeshMessage(uuid: String, element: Int, model: Int, opCode: String, value: String, callback: @escaping MeshMessageSendCallback) {
        meshMessageSendCallback = callback
        meshNetworkManager.delegate = self
        let network = meshNetworkManager.meshNetwork!
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            if let opCodeU = UInt8(opCode, radix: 16) {
                let parameters = Data(hex: value)
                let sendToModel = node.elements[element].models[model]
                let messageToSend = RuntimeVendorMessage(opCode: opCodeU, for: sendToModel, parameters: parameters)
                _ = try? meshNetworkManager.send(messageToSend, to: sendToModel)
            }
        }
    }
}

extension MeshSDK {
     func resetNode(uuid: String, callback: @escaping ResetNodeCallback) {
        self.resetNodeCallback = callback
        let network = meshNetworkManager.meshNetwork!
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            let message = ConfigNodeReset()
            _ = try? meshNetworkManager.send(message, to: currentNode)

        }
    }
}

// MARK: - 添加 ApplicaitonKey
extension MeshSDK {
     func bindApplicationKeyForNode(appKey: String, uuid: String, callback: @escaping BindApplicationKeyForNodeCallback) {
        bindApplicationKeyForNodeCallback = callback
        let network = meshNetworkManager.meshNetwork!
        meshNetworkManager.delegate = self
        
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            for applicationKey in network.applicationKeys where applicationKey.key.hex == appKey {
                _ = try? meshNetworkManager.send(ConfigAppKeyAdd(applicationKey: applicationKey), to: currentNode)
            }
        }
    }
    
     func bindApplicationKeyForBaseModel(appKey: String, uuid: String, callback: @escaping BindApplicationKeyForBaseModelCallback) {
        
        bindApplicationKeyForBaseModelCallback = callback
        let network = meshNetworkManager.meshNetwork!
        for node in network.nodes where node.uuid.uuidString == uuid {
            currentNode = node
            for model in currentNode.elements[0].models where model.name == "Generic OnOff Server" {
                meshNetworkManager.delegate = self
                for applicationKey in network.applicationKeys where applicationKey.key.hex == appKey {
                    let message = ConfigModelAppBind(applicationKey: applicationKey, to: model)!
                    _ = try? meshNetworkManager.send(message, to: model)
                }
            }
        }
    }
    
     func bindApplicationKeyForCustomModel(appKey: String, uuid: String, callback: @escaping BindApplicationKeyForCustomModelCallback) {
        
        bindApplicationKeyForCustomModelCallback = callback
        let network = meshNetworkManager.meshNetwork!
        for node in network.nodes where node.uuid.uuidString == uuid {
            
            for model in currentNode.elements[0].models where model.modelIdentifier == 1 {
                currentNode = node
                meshNetworkManager.delegate = self
                for applicationKey in network.applicationKeys where applicationKey.key.hex == appKey {
                    let message = ConfigModelAppBind(applicationKey: applicationKey, to: model)!
                    _ = try? meshNetworkManager.send(message, to: model)
                }
            }

        }
    }
}

// MARK: - Export
extension MeshSDK {
    public func exportConfiguration(callback: (String) -> ()) {
        let data = meshNetworkManager.export()
        do {
            let name = meshNetworkManager.meshNetwork?.meshName ?? "mesh"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).json")
            try data.write(to: fileURL)
            callback(String(data: data, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) ?? "")
        } catch {
            print("Export Failed: \(error)")
        }
    }
}

extension MeshSDK {
    public func importConfiguration(jsonString: String, callback:(Bool) -> ()) {
        if let data = jsonString.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
            _ = try? meshNetworkManager.import(from: data)
            if meshNetworkManager.save() {
                self.meshNetworkDidChange()
                callback(true)
            } else {
                callback(false)
            }
        }
        
    }
}

extension MeshSDK: MeshNetworkDelegate {
    public func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        guard currentNode?.unicastAddress == source else {
            return
        }
        
        switch message {
        case is VendorMessage:
            if let callback = lightPropertyStatusCallback {
                callback(true)
                lightPropertyStatusCallback = nil
                self.currentNode = nil
            }
            if let callback = meshMessageSendCallback {
                callback(true)
                meshMessageSendCallback = nil
                self.currentNode = nil
            }
        case is UnknownMessage:
            let string = String(data: message.parameters!, encoding: String.Encoding.utf8)
            let handledString = string?.replacingOccurrences(of: "\0", with: " ")
            
            let arraySubstrings = handledString?.split(separator: " ")
            let arrayStrings: [String] = (arraySubstrings?.compactMap { "\($0)" })!
            let dict = ["code": 200,
                        "pk": arrayStrings[0] ,
                        "ps": arrayStrings[1] ,
                        "dn": arrayStrings[2] ,
                        "ds": arrayStrings[3] ] as [String : Any]
            quadruplesResultCallback(dict)
            quadruplesResultCallback = nil
            currentNode = nil
            
        case is ConfigNodeResetStatus:
            self.resetNodeCallback(true)
            self.resetNodeCallback = nil
            self.currentNode = nil
        case is GenericOnOffStatus:
            if let callback = genericOnOffStatusCallback {
                callback(true)
                genericOnOffStatusCallback = nil
                currentNode = nil
            }
        case is ConfigCompositionDataStatus:
            print("配置组成数据状态")
            self.getTtl(uuid: currentNode.uuid.uuidString)
        case is ConfigDefaultTtlStatus:
            print("配置默认TTL状态")
        case is ConfigNodeResetStatus:
            print("配置重置节点状态")
        case is ConfigAppKeyStatus:
            print("配置 ApplicationKey 状态")
            if let callback = bindApplicationKeyForNodeCallback {
                callback(["code": 200])
                bindApplicationKeyForNodeCallback = nil
                DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                    self.getCompositionData(uuid: self.currentNode.uuid.uuidString)
                    self.currentNode = nil

                }
            }
        case is ConfigModelAppStatus:
            print("Model 配置 ApplicationKey 的状态")
            if let callback = bindApplicationKeyForBaseModelCallback {
                callback(["code": 200])
                bindApplicationKeyForBaseModelCallback = nil
                currentNode = nil
            }
            
            if let callback = bindApplicationKeyForCustomModelCallback {
                callback(["code": 200])
                bindApplicationKeyForCustomModelCallback = nil
                currentNode = nil
            }
        default:
            print("我也不知道这是什么")
            break
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager, didSendMessage message: MeshMessage, from localElement: Element, to destination: Address) {
        
    }
}

// MARK: - Provision
extension MeshSDK: ProvisioningDelegate {
    public func provision(identifier: String, networkKey: String) {
        let indexOfDevice = self.disposedDiscoveredDevices.firstIndex { $0.identifier == identifier }!
        unprovisionedDevice = discoveredPeripherals[indexOfDevice].device
        bearer = PBGattBearer(target: discoveredPeripherals[indexOfDevice].peripheral)
        
        bearer.delegate = self
        bearer.open()
        phase = .identifying
        provisioningNetworkKey = networkKey
    }
    
     func provision(identifier: String, networkKey: String, callback: @escaping ProvisioningStatusCallback) {
        provisioningStatusCallback = callback
        let indexOfDevice = self.disposedDiscoveredDevices.firstIndex { $0.identifier == identifier }!
        unprovisionedDevice = discoveredPeripherals[indexOfDevice].device
        bearer = PBGattBearer(target: discoveredPeripherals[indexOfDevice].peripheral)
        
        bearer.delegate = self
        bearer.open()
        phase = .identifying
        provisioningNetworkKey = networkKey
    }
    
    private func setupProvisionManager(unprovisionDevice: UnprovisionedDevice, bearer: ProvisioningBearer) {
        let network = meshNetworkManager.meshNetwork!
        self.bearer = bearer
        self.bearer.delegate = self
        provisioningManager = network.provision(unprovisionedDevice: unprovisionDevice, over: self.bearer)
        provisioningManager.delegate = self
        
        do {
            try self.provisioningManager.identify(andAttractFor: 5)
        } catch {
            self.abort(bearer: bearer)
        }
    }
    
    func abort(bearer: ProvisioningBearer) {
        bearer.close()
    }
    
    public func authenticationActionRequired(_ action: AuthAction) {
        
    }
    
    public func inputComplete() {
        print("inputComplete\nProvisioning...")
    }
    
    public func provisioningState(of unprovisionedDevice: UnprovisionedDevice, didChangeTo state: ProvisionigState) {
        switch state {
        case .requestingCapabilities:
            print("Identifying...")
        case .capabilitiesReceived(let capabilities):
            print("ElementCount \(capabilities.numberOfElements)")
            print("SupportedAlgorithms \(capabilities.algorithms)")
            print("PublicKeyType \(capabilities.publicKeyType)")
            print("StaticOobType \(capabilities.staticOobType)")
            print("ouputOobSize \(capabilities.outputOobSize)")
            print("outputOobActions \(capabilities.outputOobActions)")
            print("inputOobSize \(capabilities.inputOobSize)")
            print("inputOobActions \(capabilities.inputOobActions)")
            
            let addressValid = self.provisioningManager.isUnicastAddressValid == true
            if !addressValid {
                self.provisioningManager.unicastAddress = nil
            }
            print(self.provisioningManager.unicastAddress?.asString() ?? "No address available")
            
            let capabilitiesWereAlreadyReceived = self.capabilitiesReceived
            self.capabilitiesReceived = true
            
            let deviceSupported = self.provisioningManager.isDeviceSupported == true
            if deviceSupported && addressValid {
                if capabilitiesWereAlreadyReceived {
                    print("You are able to start provision.")
                }
            } else {
                if !deviceSupported {
                    print("Selected device is not supported.")
                } else {
                    print("No available Unicast Address in Provisioner's range.")
                }
            }
            
            startProvisioning(networkKey: self.provisioningNetworkKey)
        case .complete:
            print("complete")
            self.bearer.close()
        case let .fail(error):
            print(error)
        default:
            break
        }
    }
    
    func startProvisioning(networkKey: String) {
        guard let capabilities = provisioningManager.provisioningCapabilities else {
            // TODO: 给出一个失败的回调
            return
        }
        
        let publicKeyNotAvailble = capabilities.publicKeyType.isEmpty
        guard publicKeyNotAvailble || publicKey != nil else {
            // TODO: 给出一个失败的回调
            return
        }
        
        publicKey = publicKey ?? .noOobPublicKey
        
        let staticOobNotSupported = capabilities.staticOobType.isEmpty
        let outputOobNotSupported = capabilities.outputOobActions.isEmpty
        let inputOobNotSupported  = capabilities.inputOobActions.isEmpty
        
        guard (staticOobNotSupported && outputOobNotSupported && inputOobNotSupported) || authenticationMethod != nil else {
            // TODO: 给出一个失败的回调
            return
        }
        
        if authenticationMethod == nil {
            authenticationMethod = .noOob
        }
        
        if let provisioningNetworkKey: NetworkKey = meshNetworkManager.meshNetwork!.networkKeys.first(where: { $0.key.hex == networkKey }) {
            self.provisioningManager.networkKey = provisioningNetworkKey
            do {
                try self.provisioningManager.provision(usingAlgorithm: .fipsP256EllipticCurve,
                                                       publicKey: self.publicKey!,
                                                       authenticationMethod: self.authenticationMethod!)
            } catch {
                self.abort(bearer: self.bearer)
            }

        }
    }
}

extension MeshNetwork {
    
    func provision(unprovisionedDevice: UnprovisionedDevice, over bearer: ProvisioningBearer) -> ProvisioningManager {
        return ProvisioningManager(for: unprovisionedDevice, over: bearer, in: self)
    }
}

extension MeshSDK: GattBearerDelegate {
    public func bearer(_ bearer: Bearer, didClose error: Error?) {
        if case .complete = provisioningManager.state {
            let dict:[String: Int]
            if meshNetworkManager.save() {
                print("设备真正的添加完成")
                meshNetworkDidChange()
                dict = ["code": 200]
                self.provisioningStatusCallback(dict)
                self.provisioningStatusCallback = nil
            } else {
                dict = ["code": 201]
                self.provisioningStatusCallback(dict)
                self.provisioningStatusCallback = nil
            }
        }
    }
    
    public func bearerDidOpen(_ bearer: Bearer) {
        self.bearer = bearer as? ProvisioningBearer
        setupProvisionManager(unprovisionDevice: unprovisionedDevice, bearer: self.bearer)
    }
    
    public func bearerDidDiscoverServices(_ bearer: Bearer) {
        print("Initializing...")
    }
    
    public func bearerDidConnect(_ bearer: Bearer) {
        print("Discovering services...")
    }
}

extension MeshSDK: CBCentralManagerDelegate {
    
     func checkPermission(callback : @escaping CheckPermissionCallback) {
        checkPermissionCallBack = callback
        centralManager.delegate = self
        if centralManager.state == .poweredOn {
            callback("GRANTED", true)
        } else {
            callback("DENIED", false)
        }
    }
    
     func startScan(type: String, callback: @escaping ScanResultCallback, disposedCallback: @escaping DisposedScanResultCallback) {
        
        centralManager.delegate = self
        scanResultCallback = callback
        disposedScanResultCallback = disposedCallback
        centralManager.scanForPeripherals(withServices: [MeshProvisioningService.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
    }
    
     func startScan(type: String, callback: @escaping DisposedScanResultReadableCallback) {
        
        centralManager.delegate = self
        disposedScanResultReadableCallback = callback
        centralManager.scanForPeripherals(withServices: [MeshProvisioningService.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
     func stopScan() {
        centralManager.stopScan()
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.peripheral == peripheral }) {
            if let unprovisionedDevice = UnprovisionedDevice(advertisementData: advertisementData) {
                discoveredPeripherals.append((unprovisionedDevice, peripheral, RSSI.intValue))
//                scanResultCallback(discoveredPeripherals)
                //
                disposedDiscoveredDevices.append((unprovisionedDevice.uuid.uuidString, RSSI.intValue, peripheral.name ?? "Unknown Device"))
//                disposedScanResultCallback(disposedDiscoveredDevices)
                
                let newlyAddDevice = ["uuid": unprovisionedDevice.uuid.uuidString, "rssi": RSSI.intValue, "name": peripheral.name ?? ""] as [String : Any]
                disposedDiscoveredReadableDevices.append(newlyAddDevice)
                disposedScanResultReadableCallback(disposedDiscoveredReadableDevices)
                
            } else {
                if let index = discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) {
                    print(index)
                }
            }
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            if let _ = checkPermissionCallBack {
                checkPermissionCallBack("DENIED", false)
            }
        } else {
            if let _ = checkPermissionCallBack {
                checkPermissionCallBack("GRANTED", true)
            }
            
//            if central.state == .poweredOn {
//                startScan(type: "")
//            }
        }
    }
}

//extension MeshNetworkManager {
//
//    static var instance: MeshNetworkManager! {
//        return MeshSDK().meshNetworkManager
//    }
//
//    static var bearer: NetworkConnection! {
//        return MeshSDK().connection
//    }
//}

extension MeshSDK: LoggerDelegate {
    public func log(message: String, ofCategory category: LogCategory, withLevel level: LogLevel) {
        if #available(iOS 10.0, *) {
            os_log("%{public}@", log: category.log, type: level.type, message)
        } else {
            NSLog("%@", message)
        }
    }
}

extension LogLevel {
    
    /// Mapping from mesh log levels to system log types.
    var type: OSLogType {
        switch self {
        case .debug:       return .debug
        case .verbose:     return .debug
        case .info:        return .info
        case .application: return .default
        case .warning:     return .error
        case .error:       return .fault
        }
    }
    
}

extension LogCategory {
    
    var log: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier!, category: rawValue)
    }
    
}
