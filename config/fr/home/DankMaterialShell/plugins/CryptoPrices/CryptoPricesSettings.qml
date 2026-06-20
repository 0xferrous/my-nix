import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "cryptoPrices"

    StyledText {
        width: parent.width
        text: "Crypto Prices Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Track comma-separated Binance symbols like ETHUSDT,BTCUSDT,SOLUSDT. Click the widget to refresh immediately. Right-click it to toggle 24h percentages."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "symbolsCsv"
        label: "Symbols"
        description: "Comma-separated Binance spot symbols"
        placeholder: "ETHUSDT,BTCUSDT,FUELUSDT,ARBUSDT,SOLUSDT"
        defaultValue: "ETHUSDT,BTCUSDT,FUELUSDT,ARBUSDT,SOLUSDT"
    }

    SliderSetting {
        settingKey: "refreshIntervalSec"
        label: "Refresh Interval"
        description: "How often prices are refreshed"
        defaultValue: 10
        minimum: 5
        maximum: 86400
        unit: "s"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "showPercentages"
        label: "Show 24h Change"
        description: "Show 24 hour percentage moves beside each price"
        defaultValue: true
    }
}
