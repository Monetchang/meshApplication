//
//  RCTMesh.m
//  application
//
//  Created by MXCHIP on 2019/12/23.
//  Copyright © 2012-2019 MXCHIP - Smart Plus Team. All rights reserved.
//

#import "RCTBLEMesh.h"
#import "meshApllication-Swift.h"


@implementation RCTBLEMesh
{
  
}

RCT_EXPORT_MODULE(BLEMesh);
- (NSArray<NSString *> *)supportedEvents
{
  return @[
           @"mesh",
           @"mesh_on_scan",
           @"mesh_on_connect",
           @"mesh_on_disconnect",
           @"BLEMesh_onScanResult",
           @"BLEMesh_onProvisionStep"
           ];
}

// 加载应用页面
// MARK: ⌘
// MARK: setup()
RCT_EXPORT_METHOD(setup)
{
  [[MeshSDK sharedInstance] setup];
}

// 检查权限
// MARK: ⌘
// MARK: checkPermission(callback)
RCT_EXPORT_METHOD(checkPermission:(RCTResponseSenderBlock)callback)
{
  [[MeshSDK sharedInstance] checkPermissionWithCallback:^(NSString * permission, BOOL success) {
    callback(@[permission]);
  }];
}

// NetworkKey extension
// MARK: NetworkKey
RCT_EXPORT_METHOD(createNetworkKey: (NSString *)key) {
  [[MeshSDK sharedInstance] createNetworkKeyWithKey:key];
};

RCT_EXPORT_METHOD(removeNetworkKey: (NSString *)key) {
  [[MeshSDK sharedInstance] deleteNetworkKeyWithKey:key];
};

RCT_EXPORT_METHOD(getAllNetworkKey:(RCTResponseSenderBlock)callback)
{
  NSArray *allNetworkKeys = [[MeshSDK sharedInstance] getAllNetworkKeys];
  NSLog(@"allNetworkKeys: %@", allNetworkKeys);
  callback(@[allNetworkKeys]);
}

RCT_EXPORT_METHOD(setCurrentNetworkKey: (NSString *)key) {
  [[MeshSDK sharedInstance] setCurrentNetworkKey:key];
};

RCT_EXPORT_METHOD(getCurrentNetworkKey:(RCTResponseSenderBlock)callback) {
  NSString *networkKey = [[MeshSDK sharedInstance] getCurrentNetworkKey];
  callback(@[networkKey]);
};

// ApplicationKey extension
// MARK: ApplicationKey
RCT_EXPORT_METHOD(createApplicationKey: (NSString *)networkKey){
  [[MeshSDK sharedInstance] createApplicationKeyWithNetworkKey:networkKey];
};

RCT_EXPORT_METHOD(removeApplicationKey: (NSString *)appKey networkKey:(NSString *)networkKey){
  [[MeshSDK sharedInstance] removeApplicationKeyWithAppKey:appKey networkKey:networkKey];
};

RCT_EXPORT_METHOD(getAllApplicationKey: (NSString *)networkKey callback:(RCTResponseSenderBlock)callback) {
  NSArray *allApplicationKeys = [[MeshSDK sharedInstance] getAllApplicationKeyWithNetworkKey:networkKey];
  NSLog(@"allApplicationKeys: %@", allApplicationKeys);
  callback(@[allApplicationKeys]);
};

RCT_EXPORT_METHOD(setCurrentApplicationKey: (NSString *)appKey networkKey: (NSString *)networkKey){
  [[MeshSDK sharedInstance] setCurrentApplicationKeyWithKey:appKey networkKey:networkKey];
};

RCT_EXPORT_METHOD(getCurrentApplicationKey:(RCTResponseSenderBlock)callback) {
  NSString *applicationKey = [[MeshSDK sharedInstance] getCurrentApplicationKey];
  callback(@[applicationKey]);
};

// 蓝牙设备扫描
// MARK: Scan
RCT_EXPORT_METHOD(startScan: (NSString *)type callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] startScanWithType:type callback:^(NSArray<NSDictionary<NSString *,id> *> * result) {
    [self sendEventWithName:@"BLEMesh_onScanResult" body:result];
  }];
};

RCT_EXPORT_METHOD(stopScan){
  [[MeshSDK sharedInstance] stopScan];
};

// 蓝牙配网
// MARK: Provision
RCT_EXPORT_METHOD(provision: (NSString *)identifier networkKey: (NSString *)networkKey) {
  [[MeshSDK sharedInstance] provisionWithIdentifier:identifier networkKey: networkKey callback:^(NSDictionary<NSString *,NSNumber *> * result) {
    [self sendEventWithName:@"BLEMesh_onProvisionStep" body:result];
  }];
};

// 绑定 AppKey
// MARK: Bind ApplicationKey
RCT_EXPORT_METHOD(bindApplicationKeyForNode: (NSString *)uuid appKey:(NSString *)appKey callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] bindApplicationKeyForNodeWithAppKey:appKey uuid:uuid callback:^(NSDictionary<NSString *,NSNumber *> * result) {
    callback(@[result]);
  }];
}

RCT_EXPORT_METHOD(bindApplicationKeyForBaseModel: (NSString *)uuid appKey:(NSString *)appKey callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] bindApplicationKeyForBaseModelWithAppKey:appKey uuid:uuid callback:^(NSDictionary<NSString *,NSNumber *> * result) {
    callback(@[result]);
  }];
}

// 获取本地已经配置的节点
// MARK: Get Provisioned Nodes
RCT_EXPORT_METHOD(getProvisionedNodes: (RCTResponseSenderBlock)callback) {
  [[MeshSDK sharedInstance] getProvisionedNodesWithCallback:^(NSArray<NSDictionary<NSString *,id> *> * result) {
    callback(@[result]);
  }];
};

// 对设备发送控制指令
// MARK: Send Message
RCT_EXPORT_METHOD(setGenericOnOff: (NSString *)uuid value: (BOOL)value callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] setGenericOnOffWithUuid:uuid isOn:value callback:^(BOOL success) {
    callback(@[@(success)]);
  }];
};

RCT_EXPORT_METHOD(setLightProperties: (NSString *)uuid c:(NSInteger *)c w:(NSInteger *)w r:(NSInteger *)r g:(NSInteger *)g b:(NSInteger *)b callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] setLightPropertiesWithUuid:uuid c:c w:w r:r g:g b:b callback:^(BOOL success) {
    callback(@[@(success)]);
  }];
};

RCT_EXPORT_METHOD(sendMeshMessage: (NSString *)uuid element:(NSInteger *)element model:(NSInteger *)model opcode:(NSString *)opcode value:(NSString *)value callback: (RCTResponseSenderBlock)callback){
  //  [[MeshSDK sharedInstance] sendMess];
};

// 重置
// MARK: Reset Node
RCT_EXPORT_METHOD(resetNode: (NSString *)uuid){
  //  [[MeshSDK sharedInstance]reset]
};

// 网络的导入和导出
// MARK: Mesh Netwok
RCT_EXPORT_METHOD(exportConfiguration: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] exportConfigurationWithCallback:^(NSString * result) {
    callback(@[result]);
  }];
};

RCT_EXPORT_METHOD(importConfiguration: (NSString *)data callback: (RCTResponseSenderBlock)callback){
  [[MeshSDK sharedInstance] importConfigurationWithJsonString:data callback:^(BOOL success) {
    callback(@[@(success)]);
  }];
};

@end

