import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "tailscaleActive"

    StyledText {
        width: parent.width
        text: "Tailscale Active Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shows the account value from the active row in `tailscale switch --list`. Click the widget to refresh immediately."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "refreshIntervalSec"
        label: "Refresh Interval"
        description: "How often the active Tailscale account is refreshed"
        defaultValue: 60
        minimum: 10
        maximum: 3600
        unit: "s"
        leftIcon: "schedule"
    }
}
