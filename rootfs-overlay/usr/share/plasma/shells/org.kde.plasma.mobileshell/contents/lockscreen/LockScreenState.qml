// SPDX-FileCopyrightText: 2022-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQml
import QtQuick

import org.kde.kscreenlocker 1.0 as ScreenLocker

QtObject {
    id: root

    // current password being typed
    property string password: ""

    // whether waiting for authentication after trying password
    property bool waitingForAuth: false

    // the info message given
    property string info: ""

    // whether the lockscreen can be unlocked (no password needed, passwordless login)
    readonly property bool canBeUnlocked: authenticator.unlocked

    // whether the device can log in with fingerprint
    readonly property bool isFingerprintSupported: authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint

    // whether we are in keyboard mode (hiding the numpad)
    property bool isKeyboardMode: false

    property string pinLabel: enterPinLabel
    readonly property string enterPinLabel: i18n("Enter PIN")
    readonly property string wrongPinLabel: i18n("Wrong PIN")

    // m52xq: after a resume kscreenlocker answers its own fresh PAM conversation with an empty password
    // ("pam_unix: conversation failed"); that queued failure reaches the first real attempt within a few ms,
    // before PAM has checked anything. A failure that fast is stale: try the same password once more.
    property double attemptTime: 0
    property bool staleRetried: false

    property var staleRetryTimer: Timer {
        interval: 300
        onTriggered: root.tryPassword()
    }

    signal reset()
    signal unlockSucceeded()
    signal unlockFailed()

    Component.onCompleted: authenticator.startAuthenticating();

    function tryPassword() {
        // ensure it's in authenticating state (it might get unset after suspend)
        authenticator.startAuthenticating();

        // prevent typing lock when password is empty
        if (root.password !== '') {
            root.waitingForAuth = true;
        }
        root.attemptTime = Date.now();
        console.log('attempt password');
        authenticator.respond(root.password);
    }

    function resetPassword() {
        password = "";
        root.reset();
    }

    function resetPinLabel(): void {
        pinLabel = enterPinLabel;
    }

    property var graceLockTimer: Timer {
        interval: 3000
        onTriggered: {
            root.waitingForAuth = false;
            root.password = "";
            authenticator.startAuthenticating();
        }
    }

    property var connections: Connections {
        target: authenticator

        function onSucceeded() {
            if (authenticator.hadPrompt) {
                console.log('login succeeded');
                root.staleRetried = false;
                root.waitingForAuth = false;
                root.unlockSucceeded();
                Qt.quit();
            }
        }

        function onFailed(kind: int): void {
            if (kind != 0) { // if this is coming from the noninteractive authenticators
                return;
            }
            if (!root.staleRetried && root.password !== '' && Date.now() - root.attemptTime < 500) {
                root.staleRetried = true;
                console.log('stale login failure after resume, retrying');
                staleRetryTimer.restart();
                return;
            }
            root.staleRetried = false;
            console.log('login failed');
            graceLockTimer.restart();
            root.pinLabel = root.wrongPinLabel;
            root.unlockFailed();
        }

        function onInfoMessageChanged() {
            console.log('info: ' + authenticator.infoMessage);
            root.info += authenticator.infoMessage + " ";
        }

        // TODO
        function onErrorMessageChanged() {
            console.log('error: ' + authenticator.errorMessage);
        }

        // TODO
        function onPromptChanged() {
            console.log('prompt: ' + authenticator.prompt);
        }

        function onPromptForSecretChanged() {
            console.log('prompt secret: ' + authenticator.promptForSecret);
        }
    }
}
