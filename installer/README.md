## 📦 Install NativeTouch (macOS)

1. **Drag NativeTouch into your Applications folder.**
   > **Note:** This is a crucial step. Running the app from your Downloads folder can cause "Translocation" errors that break its functionality.

---

## 🚀 First Time Launch
Because NativeTouch is an independent tool, macOS needs a quick "manual handshake" to trust it.

1.  Open the **Terminal** app.
2.  Paste the following command and press **Enter**:
    ```bash
    xattr -rd com.apple.quarantine /Applications/NativeTouch.app
    ```
3.  Go to your **Applications** folder.
4.  **Right-click** NativeTouch and select **Open**.
5.  Click **Open** one last time on the popup.

---

## 🛠 Granting Permissions
Once the app starts, you will see a request for **Accessibility Access**. This is required so the app can convert your device's touch data into mouse movements.

1.  Click **Open Privacy Settings** in the popup.
2.  In the window that opens, find **NativeTouch** in the list.
3.  **Toggle the switch to ON** (you may need to enter your Mac password).
4.  NativeTouch will detect the change and prompt you to **Relaunch**. 

**Success!** The app is now ready to use.

---

### ⚡ Troubleshooting: "App won't open"
If the app still refuses to launch after Step 2:
1.  Go to **System Settings → Privacy & Security**.
2.  Scroll down to the **Security** section.
3.  Look for a message saying "NativeTouch was blocked" and click **Open Anyway**.

