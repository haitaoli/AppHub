/**
 * https://stackoverflow.com/questions/48672361/how-to-capture-notifications-in-a-wkwebview
 * Incomplete Notification API override to enable native notifications.
 */

class NotificationOverride {
    // Grant permission by default to keep this example simple.
    // Safari 13 does not support class fields yet, so a static getter must be used.
    static get permission() {
        return "granted";
    }

    // Safari 13 still uses callbacks instead of promises.
    static requestPermission (callback) {
        callback("granted");
    }

    // Forward the notification text to the native app through the script message handler.
    constructor (title, options) {
        window.webkit.messageHandlers.notify.postMessage({"title": title, "options": options});
    }
}

// Override the global browser notification object.
window.Notification = NotificationOverride;
