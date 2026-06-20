import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string defaultSymbolsCsv: "ETHUSDT,BTCUSDT,FUELUSDT,ARBUSDT,SOLUSDT"
    property string symbolsCsv: pluginData.symbolsCsv || defaultSymbolsCsv
    property int refreshIntervalSec: pluginData.refreshIntervalSec || 10
    property bool showPercentages: pluginData.showPercentages !== undefined ? pluginData.showPercentages : true

    property var trackedSymbols: parseSymbols(symbolsCsv)
    property var prices: []
    property bool loading: false
    property string errorText: ""
    property string lastUpdatedText: "never"
    property double lastUpdatedEpochMs: 0
    property int refreshTicker: 0
    property int refreshAgeSec: lastUpdatedEpochMs > 0 ? Math.max(0, Math.floor(((Date.now() + refreshTicker) - lastUpdatedEpochMs) / 1000)) : -1
    property string refreshAgeText: refreshAgeSec >= 0 ? `${refreshAgeSec}s` : ""
    property string _pendingStdout: ""
    property double fetchStartedEpochMs: 0
    property int fetchTimeoutSec: 20

    function parseSymbols(csv) {
        return csv.split(",").map(s => s.trim().toUpperCase()).filter(s => s.length > 0)
    }

    function displayName(symbol) {
        return symbol.replace(/USDT$/, "")
    }

    function formatPrice(price) {
        const value = Number(price)
        if (!Number.isFinite(value))
            return "?"
        if (value >= 1000)
            return value.toFixed(0)
        if (value >= 1)
            return value.toFixed(2)
        return value.toFixed(4)
    }

    function formatChange(changePercent) {
        const value = Number(changePercent)
        if (!Number.isFinite(value))
            return ""
        const sign = value > 0 ? "+" : ""
        return `${sign}${value.toFixed(2)}%`
    }

    function changeColor(changePercent) {
        const value = Number(changePercent)
        if (!Number.isFinite(value) || value === 0)
            return Theme.surfaceVariantText
        return value > 0 ? Theme.primary : Theme.error
    }

    function parsePayload(raw) {
        const payload = JSON.parse(raw)
        const bySymbol = {}
        for (let i = 0; i < payload.length; i++)
            bySymbol[payload[i].symbol] = payload[i]

        const nextPrices = []
        for (let i = 0; i < trackedSymbols.length; i++) {
            const symbol = trackedSymbols[i]
            const item = bySymbol[symbol]
            if (!item)
                continue

            nextPrices.push({
                symbol: symbol,
                name: displayName(symbol),
                rawPrice: Number(item.lastPrice),
                priceText: formatPrice(item.lastPrice),
                rawChangePercent: Number(item.priceChangePercent),
                changeText: formatChange(item.priceChangePercent),
                changeColor: changeColor(item.priceChangePercent)
            })
        }

        prices = nextPrices
        errorText = nextPrices.length > 0 ? "" : "No data"
        lastUpdatedEpochMs = Date.now()
        lastUpdatedText = new Date(lastUpdatedEpochMs).toLocaleTimeString()
    }

    function fetchPrices() {
        if (fetchProcess.running) {
            const fetchAgeSec = Math.floor((Date.now() - fetchStartedEpochMs) / 1000)
            if (fetchStartedEpochMs > 0 && fetchAgeSec >= fetchTimeoutSec) {
                console.warn(`cryptoPrices fetch stuck for ${fetchAgeSec}s, restarting`)
                fetchProcess.running = false
            } else {
                return
            }
        }

        if (trackedSymbols.length === 0) {
            prices = []
            errorText = "No symbols configured"
            loading = false
            return
        }

        loading = true
        errorText = ""
        _pendingStdout = ""
        fetchStartedEpochMs = Date.now()
        fetchProcess.command = ["curl", "-fsSL", "--connect-timeout", "10", "--max-time", String(fetchTimeoutSec), "https://api.binance.com/api/v3/ticker/24hr"]
        fetchProcess.running = true
    }

    function togglePercentages() {
        pluginService?.savePluginData("cryptoPrices", "showPercentages", !showPercentages)
    }

    Process {
        id: fetchProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root._pendingStdout = text.trim()
            }
        }

        stderr: StdioCollector {
        }

        onExited: exitCode => {
            root.loading = false
            root.fetchStartedEpochMs = 0

            if (exitCode !== 0) {
                root.errorText = "Fetch failed"
                return
            }

            if (!root._pendingStdout || root._pendingStdout[0] !== "[") {
                root.errorText = "Empty response"
                return
            }

            try {
                root.parsePayload(root._pendingStdout)
            } catch (e) {
                console.warn("cryptoPrices parse error", e)
                root.errorText = "Parse failed"
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: Math.max(5, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        onTriggered: root.fetchPrices()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!fetchProcess.running || root.fetchStartedEpochMs <= 0)
                return

            const fetchAgeSec = Math.floor((Date.now() - root.fetchStartedEpochMs) / 1000)
            if (fetchAgeSec >= root.fetchTimeoutSec) {
                console.warn(`cryptoPrices watchdog stopping stuck fetch after ${fetchAgeSec}s`)
                fetchProcess.running = false
                root.loading = false
                root.errorText = "Fetch timed out"
                root.fetchStartedEpochMs = 0
                root.fetchPrices()
            }
        }
    }

    Timer {
        interval: 1000
        running: root.lastUpdatedEpochMs > 0
        repeat: true
        onTriggered: root.refreshTicker++
    }

    Component.onCompleted: fetchPrices()
    onSymbolsCsvChanged: {
        trackedSymbols = parseSymbols(symbolsCsv)
        fetchPrices()
    }
    onRefreshIntervalSecChanged: refreshTimer.restart()

    pillClickAction: () => {
        fetchPrices()
    }

    pillRightClickAction: () => {
        togglePercentages()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            StyledText {
                visible: root.loading && root.prices.length === 0
                text: "…"
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !root.loading && root.errorText.length > 0
                text: root.errorText
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: root.prices

                Row {
                    spacing: Theme.spacingXS

                    StyledText {
                        text: modelData.name + ":"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.priceText
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        visible: root.showPercentages
                        text: modelData.changeText
                        font.pixelSize: Theme.fontSizeSmall
                        color: modelData.changeColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StyledText {
                visible: root.refreshAgeSec >= 0 && root.prices.length > 0
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
                visible: root.loading && root.prices.length === 0
                text: "…"
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: !root.loading && root.errorText.length > 0
                text: root.errorText
                color: Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Repeater {
                model: root.prices

                Column {
                    spacing: 1

                    StyledText {
                        text: modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: modelData.priceText
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: root.showPercentages
                        text: modelData.changeText
                        font.pixelSize: Theme.fontSizeSmall
                        color: modelData.changeColor
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            StyledText {
                visible: root.refreshAgeSec >= 0 && root.prices.length > 0
                text: root.refreshAgeText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

}
