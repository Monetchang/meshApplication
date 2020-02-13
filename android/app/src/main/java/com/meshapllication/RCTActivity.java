package com.meshapllication;

import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.widget.ImageView;
import android.widget.RelativeLayout;

import com.facebook.react.ReactInstanceManager;
import com.facebook.react.ReactInstanceManagerBuilder;
import com.facebook.react.ReactPackage;
import com.facebook.react.ReactRootView;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.common.LifecycleState;
import com.facebook.react.devsupport.DevSupportManagerImpl;
import com.facebook.react.modules.core.DefaultHardwareBackBtnHandler;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.modules.core.PermissionAwareActivity;
import com.facebook.react.modules.core.PermissionListener;
import com.facebook.react.packagerconnection.PackagerConnectionSettings;
import com.facebook.react.shell.MainReactPackage;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

import javax.annotation.Nullable;

public class RCTActivity extends FragmentActivity implements DefaultHardwareBackBtnHandler, PermissionAwareActivity {

    private ReactRootView mReactRootView;
    private ReactInstanceManager mReactInstanceManager;

    private ReactRootView mReactRootView2;
    private ReactInstanceManager mReactInstanceManager2;

    private List<ReactRootView> mReactRootViewArray;
    private List<ReactInstanceManager> mReactInstanceManagerArray;
    private int mReactInstanceActiveIndex;
    private RelativeLayout mLayout; // 布局容器
    private ImageView mPreviewImageView; // 预览图
    private String mApplicationName;
    private @Nullable PermissionListener mPermissionListener;
    private Boolean mHidingPreviewImageVIew; // 是否正在进行隐藏预览图这遮罩动画
    private Boolean mHasBeenLaunchedLoadPanel; // 是否在当前 activity 加载过 LoadPanel（面板下载界面）
    private Boolean mInitialPanelFirstTime; // 是否第一次加载面板（下载完成后第一次加载）

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= 19 && Build.VERSION.SDK_INT < 21) {
            setWindowFlag(this, WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS, true);
        }
        if (Build.VERSION.SDK_INT >= 19) {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        }
        //make fully Android Transparent Status bar
        if (Build.VERSION.SDK_INT >= 21) {
            setWindowFlag(this, WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS, false);
            getWindow().setStatusBarColor(Color.TRANSPARENT);
        }

        ActivityCache.addActivity(this);

        initialProperties();
        setupActiveReactInstanceArrays();
        // setupReactNativeView();
        setupLayout();
        switchReactViewRender();

        Log.d("@@file_exist", panelBundleCacheFileExists() ? "YES": "NO");
    }

    /**
     * 初始化实例队列
     */
    private void setupActiveReactInstanceArrays() {
        mReactRootViewArray = Arrays.asList(null, null);
        mReactInstanceManagerArray = Arrays.asList(null, null);
        mReactInstanceActiveIndex = 1;
        mHidingPreviewImageVIew = false;
    }

    /**
     * Get 属性
     * @return
     */
    private ReactRootView getActiveReactRootView() {
        return mReactRootViewArray.get(mReactInstanceActiveIndex);
    }

    private ReactInstanceManager getActiveReactInstanceManager() {
        return mReactInstanceManagerArray.get(mReactInstanceActiveIndex);
    }

    private HashMap<String, Object> getIntentExtraData() {
        Intent intent = getIntent();
        try {
            HashMap<String, Object> options = (HashMap<String, Object>)intent.getSerializableExtra("options");
            Log.d("HashMap", options.toString());
            return options;
        } catch (RuntimeException error) {
            Log.d("getExtraData_Error", error.toString());
            return new HashMap<String, Object>();
        }
    }

    private List<ReactPackage> getPackages() {
        List<ReactPackage> packages = new ArrayList<>();

        packages.add(new MainReactPackage());
        packages.add(new CustomReactPackage());

        return packages;
    }

    @Override
    public void invokeDefaultOnBackPressed() {
        super.onBackPressed();
    }

    @Override
    protected void onStart() {
        super.onStart();
    }

    @Override
    protected void onPause() {
        super.onPause();

        sendPageLifeCycleEvent("viewDidDisappear");

        if (getActiveReactInstanceManager() != null) {
            getActiveReactInstanceManager().onHostPause(this);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        sendPageLifeCycleEvent("viewDidAppear");

        if (getActiveReactInstanceManager() != null) {
            getActiveReactInstanceManager().onHostResume(this, this);
        }
    }

    @Override
    protected void onDestroy() {
        if (getActiveReactInstanceManager() != null) {
            getActiveReactInstanceManager().onHostDestroy(this);
        }
        if (getActiveReactRootView() != null) {
            getActiveReactRootView().unmountReactApplication();
        }
        ActivityCache.removeActivity(this);

        super.onDestroy();
    }

    @Override
    protected void onStop() {
        super.onStop();
    }

    @Override
    public void onBackPressed() {
        if (getActiveReactInstanceManager() != null) {
            if (mReactInstanceActiveIndex == 0) {
                getActiveReactInstanceManager().onBackPressed();
            } else {
// todo               ApplicationBroadcastManager.topApplicationModule().finishCurrentActivity();
            }
        } else {
            super.onBackPressed();
        }
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_MENU && getActiveReactInstanceManager() != null) {
            getActiveReactInstanceManager().showDevOptionsDialog();
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }

    /**
     * 切换 React View 相关实例
     *
     */
    private void switchReactViewRender() {
        /*
         * 更新活跃实例序号
         */
        int unactiveInstanceIndex = mReactInstanceActiveIndex; // 目标非活跃实例序号
        int activeInstanceIndex = mReactInstanceActiveIndex == 0 ? 1 : 0; // 目标活跃实例序号
        mReactInstanceActiveIndex = activeInstanceIndex; // 更新 Active 中的活跃实例序号

        /*
         * 初始化当前活跃实例
         */
        setupReactInstanceByIndex(activeInstanceIndex);

        /*
         *  切换活跃实例
         */
        // 启动 React 应用
        // 注意这里的MyReactNativeApp必须对应“index.js”中的
        // “AppRegistry.registerComponent()”的第一个参数
        String moduleName = this.getBundleModuleName();
        mReactRootViewArray.get(activeInstanceIndex).startReactApplication(
                mReactInstanceManagerArray.get(activeInstanceIndex),
                moduleName,
                null
        );
        // 设定项目初始化参数
        // 设定 React 应用根 Component Props
        Bundle reactComponentProps = new Bundle();
        HashMap<String, Object> initialOptionsProptiesForReactNativeRootComponent = getIntentExtraData();
        if (mHasBeenLaunchedLoadPanel) {
            mInitialPanelFirstTime = true;
        }
        HashMap<String, Object> configPropties = new HashMap<String, Object>();
        if (initialOptionsProptiesForReactNativeRootComponent.containsKey("config")) {
            try {
                configPropties = (HashMap<String, Object>)initialOptionsProptiesForReactNativeRootComponent.get("config");
            } catch (Exception e) {
                // 类型转换失败
                Log.e("RCTActivity", "convert props.options.config to HashMap<String, Object> error.");
            }
        }
        configPropties.put("initialPanelFirstTime", mInitialPanelFirstTime);
        initialOptionsProptiesForReactNativeRootComponent.put("config", configPropties);
        reactComponentProps.putBundle("options", Arguments.toBundle(Arguments.makeNativeMap(initialOptionsProptiesForReactNativeRootComponent)));
        mReactRootViewArray.get(activeInstanceIndex).setAppProperties(reactComponentProps);

        // 切换为主 View
        mLayout.addView(mReactRootViewArray.get(activeInstanceIndex), new RelativeLayout.LayoutParams(
                RelativeLayout.LayoutParams.MATCH_PARENT,
                RelativeLayout.LayoutParams.MATCH_PARENT
        ));
        mReactRootViewArray.get(activeInstanceIndex).bringToFront();
        //todo: 移动此逻辑
        displayPreviewView();

        // 激活 View
        getActiveReactInstanceManager().onHostResume(this);

        /*
         *  回收原实例
         */
        if (mReactRootViewArray.get(unactiveInstanceIndex) != null && mReactInstanceManagerArray.get(unactiveInstanceIndex) != null) {
            mLayout.removeView(mReactRootViewArray.get(unactiveInstanceIndex));
            mReactInstanceManagerArray.get(unactiveInstanceIndex).onHostPause(this);
            mReactInstanceManagerArray.get(unactiveInstanceIndex).onHostDestroy(this);
            mReactRootViewArray.get(unactiveInstanceIndex).unmountReactApplication();
            mReactInstanceManagerArray.set(unactiveInstanceIndex, null);
            mReactRootViewArray.set(unactiveInstanceIndex, null);
        }
    }

    private void displayPreviewView() {
        // debug 模式不显示预览图
        if (BuildConfig.DEBUG ) {
            return;
        }
        // 判断是否需要显示预览图
        HashMap<String, Object> loadOptions = getIntentExtraData();
        if (loadOptions.containsKey("config")) {
            HashMap<String, Object> config = (HashMap<String, Object>) loadOptions.get("config");
            if (config.containsKey("displayScreenshot")) {
                Boolean displayScreenshot = Boolean.parseBoolean(config.get("displayScreenshot").toString());
                if (!displayScreenshot) {
                    // 面板加载参数标记不需要加载预览图
                    return;
                }
            }
        }

        if (mApplicationName != null && mApplicationName.length() > 0) {
            String previewImageFilePath = bundleDirPathForBundleName(mApplicationName) + "/main.png";
            if (!fileExists(previewImageFilePath)) {
                // file not exist
            } else {
                mPreviewImageView = new ImageView(this);
                mPreviewImageView.setBackgroundColor(Color.parseColor("#FF6B68")); // red
                mPreviewImageView.getBackground().setAlpha(128);
                mPreviewImageView.setImageURI(Uri.parse(previewImageFilePath)); //todo: 测试此逻辑
                mPreviewImageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
                mLayout.addView(mPreviewImageView, new RelativeLayout.LayoutParams(
                        RelativeLayout.LayoutParams.MATCH_PARENT,
                        RelativeLayout.LayoutParams.MATCH_PARENT
                ));
            }
        } else {
            // 应用主框架
            // LoadingDialog.getInstance(this).show();
        }

        if (mPreviewImageView != null) {
            mPreviewImageView.bringToFront();
        }
    }

    /**
     * 检查目标本地 bundle 文件是否存在
     * @return
     */
    private String getBundleModuleName() {
        HashMap<String, Object> loadOptions = getIntentExtraData();
        // 判断是否是加载主框架
        if (loadOptions.get("moduleName") == null) {
            return "application";
        }

        // 获取默认的 moduleName
        String moduleName = loadOptions.get("moduleName").toString();

        // 判断是否需要在线加载开发过程中的代码
        Boolean online = loadOptions.get("online") == null ? false : loadOptions.get("online") != null && Boolean.TRUE.equals(loadOptions.get("online"));
        if (online) {
            return moduleName;
        }

        // 需要加载 release 版本的面板包
        // 判断本地是否存在目标面板包文件
        String applicationName = loadOptions.get("applicationName") == null ? "" : loadOptions.get("applicationName").toString();
        String bundleFileCachePath = bundleFilePathForBundleName(applicationName);
        Boolean bundleFileCacheExists = fileExists(bundleFileCachePath);
        // 本地存在面板包，直接返回目标 moduleName
        if (bundleFileCacheExists) {
            return moduleName;
        }
        // 若不存在，需在线下载面板包，修改 moduleName 为面板包默认值 main
        moduleName = "main";
        return moduleName;
    }

    private void setupReactInstanceByIndex(int index) {
        mReactRootViewArray.set(index, new ReactRootView(this));

        // create ReactInstanceManagerBuilder
        ReactInstanceManagerBuilder builder = ReactInstanceManager.builder()
                .setApplication(this.getApplication())
                .addPackages(getPackages());
        // set jsbundle file if is release package mode
        HashMap<String, Object> loadOptions = getIntentExtraData();
        Boolean online = loadOptions.get("online") == null ? false : loadOptions.get("online") != null && Boolean.TRUE.equals(loadOptions.get("online"));
        String host = loadOptions.get("host") != null ? loadOptions.get("host").toString() : "localhost";
        String port = loadOptions.get("port") != null ? loadOptions.get("port").toString() : "8080";
        String applicationName = loadOptions.get("applicationName") == null ? "" : loadOptions.get("applicationName").toString();
        Boolean thisIsTheFirstActivity = loadOptions.get("online") == null; // 当前 Activity 是否为最初的 Activity
        mApplicationName = applicationName;

        // 判断是否需要加载在线包进行调试
        Boolean shouldLoadOnlineReactNativePanelForDevelop;
        if (BuildConfig.DEBUG) {
            // Debug 打包模式
            shouldLoadOnlineReactNativePanelForDevelop = online || thisIsTheFirstActivity;
        } else {
            // Release 打包模式
            shouldLoadOnlineReactNativePanelForDevelop = online && ApplicationPreferencesManager.getDeveloperMode();
        }
        // 判断是否需要开启 React Native 的开发模式
        Boolean shouldOpenReactNativeDeveloperSupport = BuildConfig.DEBUG ? true : ApplicationPreferencesManager.getDeveloperMode() && !thisIsTheFirstActivity;

        if (shouldLoadOnlineReactNativePanelForDevelop) {
            // 在线调试加载
            Log.d("@@LoadBundle", "online || thisIsTheFirstActivity");
            builder.setBundleAssetName("index.android.bundle")
                    .setJSMainModulePath("index");
        } else {
            /*
             * 加载离线包
             */
            Log.d("@@LoadBundle", "online || thisIsTheFirstActivity @else");
            if (thisIsTheFirstActivity) {
                Log.d("@@LoadBundle", "thisIsTheFirstActivity!!!");
                builder.setBundleAssetName("index.android.bundle");
            } else {
                Log.d("@@LoadBundle", "thisIsTheFirstActivity false");
                String bundleFileCachePath = bundleFilePathForBundleName(applicationName);
                Boolean bundleFileCacheExists = fileExists(bundleFileCachePath);
                if (bundleFileCacheExists) {
                    builder.setJSBundleFile(bundleFileCachePath);
                    // Example: {@code "assets://index.android.js" or "/sdcard/main.jsbundle"}
                } else {
                    // bundle 不存在，加载面板下载(LoadingPanel)界面
                    Boolean loadingPanelDebugMode = false; // 下载面板开发调试模式
                    if (loadingPanelDebugMode) {
                        // debug 下载界面
                        port = "8098";
                        builder.setBundleAssetName("index.android.bundle")
                                .setJSMainModulePath("index");
                    } else {
                        // 加载打包的下载界面
                        // String loadingPanelBundleFilePath = FileManager.externalStoragePathForBundleName("LoadPanel/index.mxbundle");
                        String loadingPanelBundleFilePath = bundleFilePathForBundleName("@LoadPanel");
                        builder.setJSBundleFile(loadingPanelBundleFilePath);
                    }
                    // 标记当前 activity 已加载过 LoadPanel
                    mHasBeenLaunchedLoadPanel = true;
                }
            }
        }

        // 设定初始化 host 和 port，保证初次加载请求正确
        PackagerConnectionSettings.ServerHostCache = host;
        PackagerConnectionSettings.ServerPortCache = port;

        // setup basic React builder options
        builder.setUseDeveloperSupport(shouldOpenReactNativeDeveloperSupport);
        builder.setInitialLifecycleState(LifecycleState.BEFORE_CREATE);

        // setup React instance manager
        mReactInstanceManagerArray.set(index, builder.build());

        // config bundle load information
        mReactInstanceManagerArray.get(index).setDebugServerHost(host, port);

        // just for test
        mReactInstanceManagerArray.get(index).getDevSupportManager().setDevSupportEnabled(shouldOpenReactNativeDeveloperSupport);
    }

    public void reload() {
        Log.d("@@reload","Activity reload");
        Handler mainHandler = new Handler(Looper.getMainLooper());
        final RCTActivity context = this;
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                switchReactViewRender();
            }
        });
    }


    /**
     * 根据 bundle 文件名称生成 bundle 文件缓存路径
     * @param bundleName
     * @return
     */
    private String bundleFilePathForBundleName(String bundleName) {
        String bundleFilePath = bundleDirPathForBundleName(bundleName) + "/index.mxbundle";
        return bundleFilePath;
    }
    private String bundleDirPathForBundleName(String bundleName) {
        String targetBundleName = bundleName.replace("@", "");
        String bundleFilePath = Environment.getExternalStorageDirectory() + "/" + MainApplication.getContext().getPackageName() + "/bundle/" + targetBundleName;
        return bundleFilePath;
    }

    /**
     * 判断本地缓存文件是否存在
     * @return
     */
    // todo: 删除此方法
    private boolean panelBundleCacheFileExists() {
        // 拼接 bundle 缓存文件路径
        String bundleFilePath = bundleFilePathForBundleName("SingleView");
        File bundleFile = new File(bundleFilePath);
        return bundleFile.exists();
    }

    /**
     * 检测目标路径文件文件是否存在
     * @param filePath
     * @return
     */
    private boolean fileExists(String filePath) {
        return (new File(filePath)).exists();
    }

    private void sendPageLifeCycleEvent(String event) {
        WritableMap map = new WritableNativeMap();
        map.putString("event", event);
        ApplicationBroadcastManager.sendPageLifeCycleEvent(map, this);
    }

    /**
     * 初始化布局
     */
    private void setupLayout() {
        mLayout = new RelativeLayout(this);
        // display preview path
        if (mApplicationName != null) {
            String previewImageFilePath = bundleDirPathForBundleName(mApplicationName) + "/main.jpg";
            if (!fileExists(previewImageFilePath)) {
                // file not exist
            } else {
                // 预览图显示逻辑

                // 判断是否需要显示预览图
                Boolean displayScreenshot = true;
                HashMap<String, Object> loadOptions = getIntentExtraData();
                if (loadOptions.containsKey("config")) {
                    HashMap<String, Object> config = (HashMap<String, Object>) loadOptions.get("config");
                    if (config.containsKey("displayScreenshot")) {
                        displayScreenshot = Boolean.parseBoolean(config.get("displayScreenshot").toString());
                    }
                }
                // 确定显示预览图
                if (displayScreenshot) {
                    int blackColor = Color.parseColor("#000000");
                    this.getWindow().setStatusBarColor(blackColor);
                    mLayout.setBackgroundColor(blackColor);
                    mPreviewImageView = new ImageView(this);
                    mPreviewImageView.setBackgroundColor(blackColor); // red
                    mPreviewImageView.getBackground().setAlpha(128);
                    mPreviewImageView.setImageURI(Uri.parse(previewImageFilePath)); //todo: 测试此逻辑
                    mPreviewImageView.setClickable(true);
                    mLayout.addView(mPreviewImageView, new RelativeLayout.LayoutParams(
                            RelativeLayout.LayoutParams.MATCH_PARENT,
                            RelativeLayout.LayoutParams.MATCH_PARENT
                    ));
                }
            }
        }

        setContentView(mLayout);
    }

    private void initialProperties() {
        HashMap<String, Object> loadOptions = getIntentExtraData();
        String applicationName = loadOptions.get("applicationName") == null ? "" : loadOptions.get("applicationName").toString();
        mApplicationName = applicationName;
        mHasBeenLaunchedLoadPanel = false;
        mInitialPanelFirstTime = false;
    }

    public void ready() {
        if (mPreviewImageView != null && !mHidingPreviewImageVIew) {
            UiThreadUtil.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    float animationFromValue = 1.0F;
                    float animationToValue = 0.0F;
                    Animation fadeOut = new AlphaAnimation(animationFromValue, animationToValue);
                    fadeOut.setInterpolator(new AccelerateInterpolator());
                    fadeOut.setStartOffset(0);
                    fadeOut.setDuration(500);
                    fadeOut.setAnimationListener(new Animation.AnimationListener() {
                        @Override
                        public void onAnimationStart(Animation animation) {
                            mHidingPreviewImageVIew = true;
                        }
                        @Override
                        public void onAnimationEnd(Animation animation) {
                            mLayout.removeView(mPreviewImageView);
                            mHidingPreviewImageVIew = false;
                        }
                        @Override
                        public void onAnimationRepeat(Animation animation) {
                        }
                    });

                    mPreviewImageView.startAnimation(fadeOut);
                }
            });
        }
    }

    // PermissionAwareActivity
    // Allow using PermissionsAndroid in react-native-background-location library
    // Didn't work with Expo. See https://github.com/expo/expo/issues/784
    // Copied solution from https://github.com/wix/react-native-navigation/pull/470/files
    @TargetApi(Build.VERSION_CODES.M)
    public void requestPermissions(String[] permissions, int requestCode, PermissionListener listener) {
        mPermissionListener = listener;
        requestPermissions(permissions, requestCode);
    }

    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (mPermissionListener != null && mPermissionListener.onRequestPermissionsResult(requestCode, permissions, grantResults)) {
            mPermissionListener = null;
        }
    }

    public static void setWindowFlag(Activity activity, final int bits, boolean on) {

        Window win = activity.getWindow();
        WindowManager.LayoutParams winParams = win.getAttributes();
        if (on) {
            winParams.flags |= bits;
        } else {
            winParams.flags &= ~bits;
        }
        win.setAttributes(winParams);
    }
}
