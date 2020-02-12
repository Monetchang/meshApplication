import {
    Platform,
    PermissionsAndroid,
} from "react-native"

const Android = Platform.OS !== 'ios'
const iOS = Platform.OS === 'ios'

export default {
    request: {
        BLE: () => {
            const permissionId = PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION
            PermissionsAndroid.request(permissionId).then(response => {
                // Returns once the user has chosen to 'allow' or to 'not allow' access
                console.log("permissions for bluetooth is now: " + response)
            })
        },
    },
}
