import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int refreshIntervalSec: pluginData.refreshIntervalSec || 60
    property string activeAccount: ""
    property string activeTailnet: ""
    property string activeId: ""
    property bool up: false
    property bool loading: false
    property string errorText: ""
    property double lastUpdatedEpochMs: 0
    property int refreshTicker: 0
    property int refreshAgeSec: lastUpdatedEpochMs > 0 ? Math.max(0, Math.floor(((Date.now() + refreshTicker) - lastUpdatedEpochMs) / 1000)) : -1
    property string refreshAgeText: refreshAgeSec >= 0 ? `${refreshAgeSec}s` : ""
    property string _pendingStdout: ""

    function parsePayload(raw) {
        const lines = raw.split(/\r?\n/).map(line => line.replace(/\s+$/, "")).filter(line => line.trim().length > 0)
        if (lines.length < 2)
            throw new Error("No rows")

        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim()
            const columns = line.split(/\s{2,}/).filter(part => part.length > 0)
            if (columns.length < 3)
                continue

            const account = columns[columns.length - 1]
            if (!account.includes("*"))
                continue

            activeId = columns[0]
            activeTailnet = columns.slice(1, columns.length - 1).join("  ")
            activeAccount = account.replace(/\*$/, "")
            up = true
            errorText = ""
            lastUpdatedEpochMs = Date.now()
            return
        }

        throw new Error("No active account")
    }

    function refresh() {
        if (fetchProcess.running)
            return

        loading = true
        errorText = ""
        _pendingStdout = ""
        fetchProcess.running = true
    }

    function tooltipText() {
        if (errorText.length > 0)
            return errorText
        if (activeAccount.length === 0)
            return loading ? "Loading…" : "No active account"

        const lines = [
            `Account: ${activeAccount}`,
            `Tailnet: ${activeTailnet}`,
            `ID: ${activeId}`
        ]
        if (refreshAgeText.length > 0)
            lines.push(`Updated: ${refreshAgeText} ago`)
        return lines.join("\n")
    }

    popoutWidth: 320
    popoutHeight: 160

    popoutContent: Component {
        Rectangle {
            color: Theme.surface
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.outlineMedium

            Column {
                x: Theme.spacingM
                y: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingS

                StyledText {
                    text: "Tailscale Active"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    visible: root.loading && root.activeAccount.length === 0
                    text: "Loading…"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: !root.loading && root.errorText.length > 0
                    text: root.errorText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    wrapMode: Text.Wrap
                }

                StyledText {
                    visible: root.activeAccount.length > 0
                    text: `Account: ${root.activeAccount}`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.Wrap
                }

                StyledText {
                    visible: root.activeTailnet.length > 0
                    text: `Tailnet: ${root.activeTailnet}`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }

                StyledText {
                    visible: root.activeId.length > 0
                    text: `ID: ${root.activeId}`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: root.refreshAgeText.length > 0
                    text: `Updated: ${root.refreshAgeText} ago`
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    Process {
        id: fetchProcess
        running: false
        command: ["sh", "-c", "(tailscale status >/dev/null 2>&1 || ~/.nix-profile/bin/tailscale status >/dev/null 2>&1 || /run/current-system/sw/bin/tailscale status >/dev/null 2>&1) || exit 1; tailscale switch --list 2>/dev/null || ~/.nix-profile/bin/tailscale switch --list 2>/dev/null || /run/current-system/sw/bin/tailscale switch --list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root._pendingStdout = text.trim()
            }
        }

        stderr: StdioCollector {}

        onExited: exitCode => {
            root.loading = false

            if (exitCode !== 0) {
                root.up = false
                root.activeAccount = ""
                root.activeTailnet = ""
                root.activeId = ""
                root.errorText = "down"
                return
            }

            try {
                root.parsePayload(root._pendingStdout)
            } catch (e) {
                console.warn("tailscaleActive parse error", e)
                root.up = false
                root.activeAccount = ""
                root.activeTailnet = ""
                root.activeId = ""
                root.errorText = e.message || "Parse failed"
            }
        }
    }

    Timer {
        interval: Math.max(10, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        running: root.lastUpdatedEpochMs > 0
        repeat: true
        onTriggered: root.refreshTicker++
    }

    Component.onCompleted: refresh()
    onRefreshIntervalSecChanged: refresh()

    pillClickAction: () => refresh()

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            StyledText {
                text: "\uf012"
                font.pixelSize: Theme.fontSizeSmall
                color: root.up ? Theme.primary : Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.loading && root.activeAccount.length === 0
                text: "…"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !root.loading && root.errorText.length > 0
                text: root.errorText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.activeAccount.length > 0 && root.errorText.length === 0
                text: root.activeAccount
                font.pixelSize: Theme.fontSizeSmall
                color: root.up ? Theme.primary : Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.refreshAgeText.length > 0 && root.activeAccount.length > 0 && root.errorText.length === 0
                text: `· ${root.refreshAgeText}`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            StyledText {
                text: "\uf012"
                font.pixelSize: Theme.fontSizeSmall
                color: root.up ? Theme.primary : Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.loading && root.activeAccount.length === 0
                text: "…"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: !root.loading && root.errorText.length > 0
                text: root.errorText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.activeAccount.length > 0 && root.errorText.length === 0
                text: root.activeAccount
                font.pixelSize: Theme.fontSizeSmall
                color: root.up ? Theme.primary : Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.refreshAgeText.length > 0 && root.activeAccount.length > 0 && root.errorText.length === 0
                text: root.refreshAgeText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
