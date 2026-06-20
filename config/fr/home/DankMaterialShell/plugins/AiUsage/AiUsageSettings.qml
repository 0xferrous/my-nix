import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "aiUsage"

    StyledText {
        width: parent.width
        text: "AI Usage Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Displays Codex and/or Kimi Coding usage. Click the widget to toggle relative vs local reset times."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Provider Setup"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Codex: Uses codexbar CLI (must be installed and configured)\nKimi: Reads API key from ~/.pi/agent/auth.json (entry: kimi-coding.key)"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "refreshIntervalSec"
        label: "Refresh Interval"
        description: "How often usage is refreshed"
        defaultValue: 60
        minimum: 30
        maximum: 900
        unit: "s"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "showAbsoluteTimes"
        label: "Show Local Reset Times"
        description: "Show weekday/time instead of relative time remaining"
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: "Provider"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        StyledButton {
            text: "Codex"
            highlighted: (pluginData.provider || "both") === "codex"
            onClicked: pluginService?.savePluginData("aiUsage", "provider", "codex")
        }

        StyledButton {
            text: "Kimi"
            highlighted: (pluginData.provider || "both") === "kimi"
            onClicked: pluginService?.savePluginData("aiUsage", "provider", "kimi")
        }

        StyledButton {
            text: "Both"
            highlighted: (pluginData.provider || "both") === "both"
            onClicked: pluginService?.savePluginData("aiUsage", "provider", "both")
        }
    }

    StyledText {
        width: parent.width
        text: "Select which AI provider(s) to display usage for"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
