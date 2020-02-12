package com.meshapllication;

import android.os.Handler;
import android.telecom.Call;
import android.util.Log;


import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.ListIterator;
import java.util.Map;

import qk.sdk.mesh.meshsdk.MeshHelper;
import qk.sdk.mesh.meshsdk.MeshSDK;
import qk.sdk.mesh.meshsdk.callback.ArrayMapCallback;
import qk.sdk.mesh.meshsdk.callback.ArrayStringCallback;
import qk.sdk.mesh.meshsdk.callback.BooleanCallback;
import qk.sdk.mesh.meshsdk.callback.IntCallback;
import qk.sdk.mesh.meshsdk.callback.MapCallback;
import qk.sdk.mesh.meshsdk.callback.StringCallback;

public class BLEMeshModule extends ReactContextBaseJavaModule implements LifecycleEventListener {

    // event name
    private String Event_onScanResult = "BLEMesh_onScanResult";
    private String Event_onProvisionStep = "BLEMesh_onProvisionStep";

    // callback
    int callback_count_bindApplicationKeyForNode = 0;

    private ReactContext mReactContext;

    public BLEMeshModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.mReactContext = reactContext;
        Log.d("@init", "BLEMeshModule init");


        MeshSDK.INSTANCE.init(reactContext);
    }

    @Override
    public String getName() {
        return "BLEMesh";
    }

    @Override
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        // 当前模块版本号 {String}
        constants.put("version", "1.0.0");

        return constants;
    }

    @ReactMethod
    public void test(ReadableMap options, final Callback callback) {
        Log.d("@BLEMeshModule", "options: " + options.toString());

        Handler handler = new Handler(mReactContext.getMainLooper());
        handler.post(new Runnable(){

            @Override
            public void run() {
                MeshSDK.INSTANCE.startScan("unProvisioned", new ArrayMapCallback() {
                    @Override
                    public void onResult(ArrayList<HashMap<String, Object>> arrayList) {
                        Log.d("@BLEMeshModule", "onResult");
                        /*if (count == 0) {
                            callback.invoke(null, Arguments.makeNativeArray(arrayList));
                            count += 1;
                        }*/
                    }
                }, new IntCallback() {
                    @Override
                    public void onResultMsg(int i) {
                        Log.d("@BLEMeshModule", "onResultMsg");
                        callback.invoke(i);
                    }
                });
            }
        });
        /*
        MeshSDK.INSTANCE.startScan("unProvisioned", new ArrayMapCallback() {
            @Override
            public void onResult(ArrayList<HashMap<String, Object>> arrayList) {
                callback.invoke(null, Arguments.makeNativeArray(arrayList));
            }
        }, new IntCallback() {
            @Override
            public void onResultMsg(int i) {
                callback.invoke(i);
            }
        });
        //*/
    }

    @ReactMethod
    public void a() {
        Log.d("@BLEMeshModule", "a()");
    }

    // init

    @ReactMethod
    public void init() {
      MeshSDK.INSTANCE.init(mReactContext);
    }

    // permission

    @ReactMethod
    public void checkPermission(final Callback callback) {
        MeshSDK.INSTANCE.checkPermission(new StringCallback() {
            @Override
            public void onResultMsg(@NotNull String msg) {
                callback.invoke(msg);
            }
        });
    }

    // Network Key

    // ### 创建 Network Key（传入存储）
    @ReactMethod
    public void createNetworkKey(String key) {
        MeshSDK.INSTANCE.createNetworkKey(key);
    }

    // ### 删除 Network Key
    @ReactMethod
    public void removeNetworkKey(String key, Callback callback) {
        MeshSDK.INSTANCE.removeNetworkKey(key, new MapCallback() {
            @Override
            public void onResult(HashMap<String, Object> hashMap) {
                callback.invoke(hashMap.get("coded"));
            }
        });
    }

    // ### 列出所有的 Network Key
    @ReactMethod
    public void getAllNetworkKey(Callback callback){
        callback.invoke(Arguments.makeNativeArray(MeshSDK.INSTANCE.getAllNetworkKey()));
    }

    // ### 设置当前 Network Key
    @ReactMethod
    public void setCurrentNetworkKey(String key) {
        MeshSDK.INSTANCE.setCurrentNetworkKey(key);
    }

    // ### 查询当前 Network Key
    @ReactMethod
    public void getCurrentNetworkKey(Callback callback) {
        MeshSDK.INSTANCE.getCurrentNetworkKey(new StringCallback() {
            @Override
            public void onResultMsg(@NotNull String msg) {
                callback.invoke(msg);
            }
        });
    }


    // ## Application Key 的相关操作

    // ### 创建 Application Key
    @ReactMethod
    public void createApplicationKey(String key) {
        MeshSDK.INSTANCE.createApplicationKey(key);
    }

    // ### 删除 Application Key
    @ReactMethod
    public void removeApplicationKey(String applicationKey, String networkKey, Callback callback) {
        // TODO: network key
        MeshSDK.INSTANCE.removeApplicationKey(applicationKey, new IntCallback() {
            @Override
            public void onResultMsg(int code) {
                callback.invoke(code);
            }
        });
    }

    // ### 列出所有的 Application Key
    @ReactMethod
    public void getAllApplicationKey(String networkKey, Callback callback) {
        MeshSDK.INSTANCE.getAllApplicationKey(networkKey, new ArrayStringCallback() {
            @Override
            public void onResult(@NotNull ArrayList<java.lang.String> result) {
                callback.invoke(Arguments.makeNativeArray(result));
            }
        });
    }

    // ### 设置当前 Application Key
    @ReactMethod
    public void setCurrentApplicationKey(String key, String networkKey) {
        // TODO: SDK realize this API
    }

    // ### 查询当前 Application Key
    @ReactMethod
    public String getCurrentApplicationKey(String networkKey) {
        // TODO: SDK realize this API
        return "";
    }


    // ----

    // ## 蓝牙设备的扫描

    // ### 开始扫描周围的蓝牙设备
    @ReactMethod
    public void startScan(String type, Callback onErrorCallback) {
        MeshSDK.INSTANCE.startScan(type, new ArrayMapCallback() {
            @Override
            public void onResult(@NotNull ArrayList<HashMap<String, Object>> result) {
                // TODO: send message to react-native
                // multiple times
                sendEventWithArray(Event_onScanResult, result);
            }
        }, new IntCallback() {
            @Override
            public void onResultMsg(int code) {
                onErrorCallback.invoke(code);
            }
        });
    }
    /*
    type: string
    - `provisioned` 已配置网络的设备
    - `unProvisioned` 未配置网络的设备

        onScanResult: callback(Array<Map/Dictionary>)
        Map:
            - mac: string
    - rssi: int
    - name: string
    */

    // ### 停止扫描周围的蓝牙设备

    @ReactMethod
    public void stopScan() {
        MeshSDK.INSTANCE.stopScan();
    }

    // ----

    // ## 对设备进行网络配置

    // ### 对设备进行网络配置 - Provision 阶段

    @ReactMethod
    public void provision(String mac) {
        // this map callback could be call multiple times, need use send message channel to send data to react native layer
        //todo 此方法需要传networkkey
        MeshSDK.INSTANCE.provision(mac, "", new MapCallback() {
            @Override
            public void onResult(@NotNull HashMap<String, Object> result) {
//                HashMap<String,Object> newMap =new HashMap<>();
//                for (HashMap.Entry<String, Object> entry : result.entrySet()) {
//                    if(entry.getKey() instanceof String){
//                        newMap.put(entry.getKey(), entry.getValue());
//                    }
//                    if(entry.getKey() instanceof Integer) {
//                        newMap.put(String.valueOf(entry.getKey()), entry.getValue());
//                    }
//                }
                sendEventWithMap(Event_onProvisionStep, result);
                // callback.invoke(Arguments.makeNativeMap(newMap));
            }
        });
    }
    /*
    callback
    - error
      - `{code: int, message: string}`
          - code == 200 成功
        - code != 200 失败
    */

    // ### 对设备进行网络配置 - Bind Application Key 阶段
    @ReactMethod
    public void bindApplicationKeyForNode(String mac, String applicationKey, Callback callback) {
        callback_count_bindApplicationKeyForNode = 0;
        MeshSDK.INSTANCE.bindApplicationKeyForNode(mac, applicationKey, new MapCallback() {
            @Override
            public void onResult(@NotNull HashMap<String, Object> result) {
                if (callback_count_bindApplicationKeyForNode == 0) {
                    callback.invoke(Arguments.makeNativeMap(result));
                }
                callback_count_bindApplicationKeyForNode = callback_count_bindApplicationKeyForNode + 1;
            }
        });
    }

    // 先实现绑定两个基本的 model
    @ReactMethod
    public void bindApplicationKeyForBaseModel(String mac, String applicationKey, Callback callback) {
        // TODO: SDK complete this logic
    }

    // reset node
    @ReactMethod
    public void removeProvisionedNode(String uuid) {
      MeshSDK.INSTANCE.removeProvisionedNode(uuid);
    }

    @ReactMethod
    public void connect(String networkKey, Callback callback) {
        MeshSDK.INSTANCE.connect(networkKey, new MapCallback() {
            @Override
            public void onResult(@NotNull HashMap<String, Object> result) {
                callback.invoke(Arguments.makeNativeMap(result));
            }
        });
    }

    // Control Commands

    @ReactMethod
    public void setGenericOnOff(String uuid, boolean on, Callback callback) {
        MeshSDK.INSTANCE.setGenericOnOff(uuid, on, new BooleanCallback() {
            @Override
            public void onResult(boolean success) {
                callback.invoke(success);
            }
        });
    }

    @ReactMethod
    public void setLightProperties(String uuid, int c, int w, int r, int g, int b, Callback callback) {
        MeshSDK.INSTANCE.setLightProperties(uuid, c, w, r, g, b, new BooleanCallback() {
            @Override
            public void onResult(boolean success) {
                callback.invoke(success);
            }
        });
    }

    @ReactMethod
    public void getDeviceIdentityKeys(String uuid, Callback callback) {
        MeshSDK.INSTANCE.getDeviceIdentityKeys(uuid, new MapCallback() {
            @Override
            public void onResult(@NotNull HashMap<String, Object> result) {
                callback.invoke(Arguments.makeNativeMap(result));
            }
        });
    }


    /**
     * 给RN发送通知
     *
     * @param eventName
     * @param params
     */
    private void sendEvent(String eventName, ReadableMap params) {
        mReactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(
                        eventName,
                        Arguments.makeNativeMap(params.toHashMap())
                );
    }

    private void sendEventWithMap(String eventName, HashMap params) {
        mReactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(
                eventName,
                Arguments.makeNativeMap(params)
            );
    }

    private void sendEventWithArray(String eventName, List params) {
        mReactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(
                eventName,
                Arguments.makeNativeArray(params)
            );
    }

    /**
     * 监听 Activity 状态变化
     */

    @Override
    public void onHostResume() {
        // Activity `onResume`
    }

    @Override
    public void onHostPause() {
        // Activity `onPause`
    }

    @Override
    public void onHostDestroy() {
        // Activity `onDestroy`
    }

}