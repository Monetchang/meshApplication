import { NativeModules, InteractionManager } from "react-native";


const application = NativeModules.Application

class ApplicationManager {

  constructor() {
    this.developerMode = false
    /*
    this.getDeveloperMode(mode => {
      this.developerMode = !!mode
    })
    //*/
  }

  _updateDeveloperMode = mode => {
    this.developerMode = mode
  }

  loadPageWithOptions = async (options) => {

    // 应用上下文
    const context = {
      app: {},
      // product: config.product,
    }

    /*
    // 若为本地原生打包的 bundle，可传递 token
    if (/^@/ig.test(options.applicationName)) {
      const token = await Managers.DataRepositoryManager.load("localStorageTokenName")
      context.token = token
    }
    //*/

    if (this.developerMode) {
      const _options = {
        ...options,
        online: false,
        applicationName: "@DevQRCodeScanPanel",
        context,
      }
      requestAnimationFrame(() => {
        application.loadPageWithOptions(_options)
      })
      return
    }

    requestAnimationFrame(() => {
      application.loadPageWithOptions({
        ...options,
        context,
      })
    })
  }

  getDeveloperMode = (callback) => {
    application.getDeveloperMode(mode => {
      this._updateDeveloperMode(mode)
      callback(mode)
    })
  }

  /*
  getDeveloperModeAsync = async (callback) => {

  }
  */

  setDeveloperMode = (targetMode, callback) => {
    application.setDeveloperMode(targetMode, () => {
      this._updateDeveloperMode(targetMode)
      callback()
    })
  }

  /*
  setDeveloperModeAsync = async (targetMode, callback) => {

  }
  */

}

export default ApplicationManager
