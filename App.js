/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React, { useState, useEffect } from 'react';
// import { BleManager } from 'react-native-ble-plx'
import {
  SafeAreaView,
  StyleSheet,
  View,
  Text,
  StatusBar,
  TouchableOpacity,
  NativeModules,
  NativeEventEmitter,
  SectionList,
} from 'react-native';

import ApplicationManager from "./app/applicationManager"
const applicationManager = new ApplicationManager()
// const BLEManager = new BleManager()
global.applicationManager = applicationManager

// 蓝牙 mesh 模块
import permission from "./app/permission"
global.permission = permission || {}
const _BLEMeshModule = NativeModules.BLEMesh

console.log("_BLEMeshModule:", _BLEMeshModule)

const BLEMeshModule = new Proxy(_BLEMeshModule, {
  get: (target, propKey) => {
    // console.log(`BLEMeshModule get[${propKey}]`)
    if (target[propKey]) {
      return target[propKey]
    }
    // console.warn(`BLEMeshModule get[${propKey}] error, cloud not found target property :(`)
  },
})
global.BLEMeshModule = BLEMeshModule
const BLEMeshEventEmitter = new NativeEventEmitter(BLEMeshModule)
// BLEMeshEventEmitter.addListener("BLEMesh_onScanResult", (result) => {
//   console.log("@BLEMesh_onScanResult", result)
// })

const Button = (props) => {

  const onPress = props.onPress
  const title = props.title || "Default Title"

  const style = {
    container: {
      padding: 20,
      backgroundColor: "#ffffff",
      borderBottomWidth: 1,
      borderBottomColor: "rgba(0,0,0,0.1)",
    },
    title: {
      color: "#000000",
    },
  }

  return (
    <TouchableOpacity style={style.container} onPress={onPress}>
      <Text style={style.title}>{title}</Text>
    </TouchableOpacity>
  )
}

let scanResult = []
const scanType = {
  provisioned: "provisioned",
  unProvisioned: "unProvisioned",
}
let currentScanType = scanType.provisioned

const App: () => React$Node = (props) => {

  // 声明列表更新标志
  const [listUpdateTime, setListUpdateTime] = useState(new Date().getTime())
  const [currentNetworkKey, setCurrentNetworkKey] = useState("")
  const refresh = () => {
    setListUpdateTime(new Date().getTime())
  }

  console.log(props)

  useEffect(() => {
    const Event_onScanResult = BLEMeshEventEmitter.addListener("BLEMesh_onScanResult", (result) => {
      console.log("@BLEMesh_onScanResult", result)
      scanResult = result.map(item => {
        item.title = item.name
        item.onPress = () => {
          if (currentScanType === scanType.unProvisioned) {
            if(currentNetworkKey === ""){
              alert("currentNetworkKey 为空")
            }else{
              BLEMeshModule.provision(item.uuid, currentNetworkKey)
            }
          } else {
            BLEMeshModule.connect(res => {
              console.log("@connect() res", res)
            })
          }
        }
        return item
      })
      refresh()
    })

    const Event_onProvisionStep = BLEMeshEventEmitter.addListener("BLEMesh_onProvisionStep", (result) => {
      console.log("@BLEMesh_onProvisionStep", result)
    })
    return () => {
      // 清除订阅
      Event_onScanResult.remove()
      Event_onProvisionStep.remove()
    };
  });

  const listConfig = [
    {
      title: "面板分离",
      data: [
        {
          title: "加载新面板",
          onPress: () => {
            let config = {
              online: true,
              host: "localhost",
              port: "8088",
              applicationName: "application",
              moduleName: "application", // todo: 修改为 main，需修改对应的面板包
              config: {
                type: "progress",
                iotId: "",
                model: "",
              },
              package: {}
            }

            applicationManager.loadPageWithOptions(config)
          }
        },
        {
          title: "返回上一个面板",
          onPress: () => {
            applicationManager.back && applicationManager.back()
          }
        },
      ]
    },
    {
      title: "蓝牙 mesh",
      data: [
        {
          title: "刷新列表",
          onPress: () => {
            refresh()
          },
        },
        {
          title: "清空扫描列表",
          onPress: () => {
            scanResult = []
            refresh()
          },
        },
        {
          title: "init()",
          onPress: () => {
            BLEMeshModule.setup()
            // BLEMeshModule.init()
          },
        },
        {
          title: "getAllNetworkKeys()",
          onPress: () => {
            console.log("BLEMeshModule:", BLEMeshModule)
            BLEMeshModule.getAllNetworkKey(keys => {
              console.log("@getAllNetworkKey", keys)
            })
          },
        },
        {
          title: "设定默认 NetworkKey",
          onPress: () => {
            BLEMeshModule.getAllNetworkKey(keys => {
              console.log("@getAllNetworkKey", keys)
              if (keys.length === 0) {
                console.warn("本地不存在 NetworkKey")
                return
              }
              const lastestNetworkKey = keys.pop()
              BLEMeshModule.setCurrentNetworkKey(lastestNetworkKey)
              setCurrentNetworkKey(lastestNetworkKey)
              console.log("设定 NetworkKey 完成", lastestNetworkKey)
            })
          },
        },
        {
          title: "生成并保存 NetworkKey",
          onPress: () => {
            const networkKey = new Array(32).fill(0).map(() => Math.round(Math.random() * 9)).join('')
            BLEMeshModule.createNetworkKey(networkKey)
          }
        },
        {
          title: "获取当前设定的 NetworkKey",
          onPress: () => {
            BLEMeshModule.getCurrentNetworkKey(networkKey => {
              console.log("Current NetworkKey", networkKey)
            })
          }
        },
        {
          title: "getAllApplicationKey()",
          onPress: () => {
            // 获取当前 Network Key
            BLEMeshModule.getAllNetworkKey(keys => {
              console.log("@getAllNetworkKey", keys)
              if (keys.length === 0) {
                console.log("@ERROR: network key 找不到任何一个啊啊啊啊。。。")
                return
              }
              const networkKey = keys[keys.length - 1]
              console.log("@networkKey", networkKey)
              BLEMeshModule.getAllApplicationKey(networkKey, keys => {
                console.log("@getAllApplicationKey", keys)
                if (keys.length < 5 || true) {
                  // 本地不存在 application key，创建一个
                  BLEMeshModule.createApplicationKey(networkKey)
                  console.log("createApplicationKey")
                  BLEMeshModule.getAllApplicationKey(networkKey, keys => {
                    console.log("getAllApplicationKey", keys)
                  })
                }
              })
            })
            return
            BLEMeshModule.getCurrentNetworkKey(networkKey => {
              console.log("Current NetworkKey", networkKey)
              // TODO: 异常处理
              BLEMeshModule.getAllApplicationKey(networkKey, keys => {
                console.log("@getAllNetworkKey", keys)
              })
            })

          },
        },
        {
          title: "startScan(unProvisioned)",
          onPress: () => {
            // 扫描未配网设备列表
            currentScanType = scanType.unProvisioned
            BLEMeshModule.startScan("unProvisioned", (code) => {
              console.warn("startScan onError: code", code)
              // 将扫描结果更新到界面上
              refresh()
            })
          },
        },
        {
          title: "startScan(provisioned)",
          onPress: () => {
            // 扫描未配网设备列表
            currentScanType = scanType.provisioned
            BLEMeshModule.startScan("provisioned", (code) => {
              console.warn("startScan onError: code", code)
              // 将扫描结果更新到界面上
              refresh()
            })
          },
        },
        {
          title: "stopScan()",
          onPress: () => {
            BLEMeshModule.stopScan()
          },
        },
        {
          title: "//get()",
          onPress: () => {
            //BLEMeshModule.stopScan()
          },
        },
        {
          title: "绑定 Application Key",
          onPress: async () => {
            BLEMeshModule.stopScan()
            // 获取并设定当前 NetworkKey
            const getApplications = () => {
              return new Promise((resolve) => {
                BLEMeshModule.getAllNetworkKey(keys => resolve(keys))
              })
            }

            const networkKeys = await getApplications()
            if (networkKeys.length === 0) {
              console.error("T_T Can not get applications")
              return
            }
            const networkKey = networkKeys[networkKeys.length - 1]
            console.log("@setCurrentNetworkKey", networkKey)
            BLEMeshModule.setCurrentNetworkKey(networkKey)
            // 获取 application key
            BLEMeshModule.getAllApplicationKey(networkKey, applicationKeys => {
              console.log("@applicationKeys", applicationKeys)
              if (applicationKeys.length === 0) {
                // 创建 ApplicationKey
                let appKey = new Array(32).fill(0).map(() => Math.round(Math.random() * 9)).join('')
                BLEMeshModule.createApplicationKey(networkKey)
              }
              let appKey = applicationKeys[applicationKeys.length - 1]
              console.log("go bindApplicationKeyForNode~~", appKey, applicationKeys)
              BLEMeshModule.bindApplicationKeyForNode("01003510-8C04-7863-D0F1-CA0000000000", appKey, res => console.log("@res", res))
            })
            return
            // test
            appKey = "17837612352713082656279028421117"
            BLEMeshModule.bindApplicationKeyForNode("01003510-8C04-7863-D0F1-CA0000000000", appKey, res => console.log("@res", res))
          },
        },
        {
          title: "移除已配置的设备",
          onPress: () => {
            //BLEMeshModule.stopScan()
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            BLEMeshModule.removeProvisionedNode(uuid)
          },
        },
        {
          title: "connect()",
          onPress: () => {
            console.log("开始连接 - connect()")
            BLEMeshModule.getCurrentNetworkKey(networkKey => {
              console.log("Current NetworkKey", networkKey)
              BLEMeshModule.connect(networkKey, res => {
                console.log("@connect() res", res)
              })
            })

          }
        },
        {
          title: "下发开关指令 - 开",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            const open = true
            BLEMeshModule.setGenericOnOff(uuid, open, success => {
              console.log("下发开关指令 - 开", success)
            })
          }
        },
        {
          title: "下发开关指令 - 关",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            const open = false
            BLEMeshModule.setGenericOnOff(uuid, open, success => {
              console.log("下发开关指令 - 关", success)
            })
          }
        },
        {
          title: "下发指令 - 红色",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            BLEMeshModule.setLightProperties(uuid, 0, 0, 255, 0, 0, success => {
              console.log("下发指令 - 红色", success)
            })
          }
        },
        {
          title: "下发指令 - 绿色",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            BLEMeshModule.setLightProperties(uuid, 0, 0, 0, 255, 0, success => {
              console.log("下发指令 - 绿色", success)
            })
          }
        },
        {
          title: "下发指令 - 蓝色",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            BLEMeshModule.setLightProperties(uuid, 0, 0, 0, 0, 255, success => {
              console.log("下发指令 - 蓝色", success)
            })
          }
        },
        {
          title: "下发指令 - 获取四元组信息",
          onPress: () => {
            const uuid = "01003510-8C04-7863-D0F1-CA0000000000"
            BLEMeshModule.getDeviceIdentityKeys(uuid, res => {
              console.log("下发指令 - 获取四元组信息", res)
            })
          }
        },
      ]
    },
    {
      title: `扫描设备列表 ${listUpdateTime}`,
      data: scanResult,
    },
  ]

  const list = (
    <SectionList
      style={{ flexGrow: 1, height: "100%" }}
      contentContainerStyle={{ flexGrow: 1 }}
      renderItem={({ item, index, section }) => (
        <Button key={`${section}_${index}`} title={item.title} onPress={item.onPress} />
      )}
      renderSectionHeader={({ section: { title } }) => (
        <Text style={{ fontWeight: "bold", padding: 20, backgroundColor: "#f4f4f4" }}>{title}</Text>
      )}
      sections={listConfig}
      keyExtractor={(item, index) => item + index}
    />
  )

  return (
    <View style={{ flex: 1, flexDirection: "column" }}>
      <StatusBar barStyle="dark-content" />
      <SafeAreaView>
        {list}
      </SafeAreaView>
    </View>
  );
};

const styles = StyleSheet.create({
  scrollView: {
    backgroundColor: "#F5F5F5",
  },
  engine: {
    position: 'absolute',
    right: 0,
  },
  body: {
    backgroundColor: "#FFF",
  },
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: "#000",
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
    color: '#333',
  },
  highlight: {
    fontWeight: '700',
  },
  footer: {
    color: '#333',
    fontSize: 12,
    fontWeight: '600',
    padding: 4,
    paddingRight: 12,
    textAlign: 'right',
  },
});

export default App;
