// SPDX-FileCopyrightText: 2022 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick 2.15

import org.kde.plasma.networkmanagement.cellular as Cellular
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

QS.QuickSetting {
    id: root

    Cellular.CellularModemList {
        id: modemList
    }

    // m52xq dual SIM (one ModemManager modem object per SIM): primaryModem is just the first modem object, and their order
    // changes between ModemManager restarts; the mobile data profile is bound (m52xq-sim-mode) to the data SIM's modem only,
    // so with the other one first the tile said "APN needs to be configured" and opened the settings (2026-10-24).
    // Use the modem that has the profile, else the first one as before.
    property Cellular.CellularModem modem: {
        const list = modemList.modems;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].hasSim && !list[i].needsAPNAdded)
                return list[i];
        }
        return modemList.primaryModem;
    }

    text: i18n("Mobile Data")
    icon: "network-modem"
    status: {
        if (!modemList.modemAvailable) {
            return i18n("Not Available");
        } else if (modem.needsAPNAdded) {
            return i18n("APN needs to be configured in the settings");
        } else if (modem.mobileDataSupported) {
            return enabled ? i18n("On") : i18n("Off");
        } else if (modem.simEmpty) {
            return i18n("No SIM inserted");
        } else {
            return i18n("Not Available");
        }
    }

    settingsCommand: "plasma-open-settings kcm_cellular_network"
    enabled: modem ? modem.mobileDataEnabled : false

    function toggle() {
        if (!modem || modem.needsAPNAdded || !modem.mobileDataSupported) {
            // open settings if unable to toggle mobile data
            MobileShell.ShellUtil.executeCommand("plasma-open-settings kcm_cellular_network");
        } else {
            modem.mobileDataEnabled = !modem.mobileDataEnabled;
        }
    }
}
