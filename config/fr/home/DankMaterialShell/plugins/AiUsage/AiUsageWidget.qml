import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int refreshIntervalSec: pluginData.refreshIntervalSec || 60
    property bool showAbsoluteTimes: pluginData.showAbsoluteTimes !== undefined ? pluginData.showAbsoluteTimes : false
    property string provider: pluginData.provider || "both" // "codex", "kimi", "both"

    property int fetchTimeoutSec: 20
    property int clockTicker: 0

    // Common usage data structure
    property var codexData: createEmptyUsageData("codex")
    property var kimiData: createEmptyUsageData("kimi")

    function createEmptyUsageData(providerId) {
        return {
            provider: providerId,
            loading: false,
            error: "",
            userDisplay: "",
            sessionUsedPercent: -1,
            sessionResetsAt: "",
            weeklyUsedPercent: -1,
            weeklyResetsAt: "",
            updatedAt: "",
            // Provider-specific extra data for tooltips
            extra: {}
        }
    }

    function mergeData(base, patch) {
        const out = {}
        for (const key in base)
            out[key] = base[key]
        for (const key in patch)
            out[key] = patch[key]
        return out
    }

    // Provider configurations
    readonly property var providers: ({
        codex: {
            id: "codex",
            name: "Codex",
            enabled: provider === "codex" || provider === "both",
            data: codexData,
            fetch: fetchCodex,
            parse: parseCodexResponse
        },
        kimi: {
            id: "kimi",
            name: "Kimi",
            enabled: provider === "kimi" || provider === "both",
            data: kimiData,
            fetch: fetchKimi,
            parse: parseKimiResponse
        }
    })

    function getActiveProviders() {
        const active = []
        if (providers.codex.enabled) active.push(providers.codex)
        if (providers.kimi.enabled) active.push(providers.kimi)
        return active
    }

    // Utility functions
    function percentText(value) {
        const number = Number(value)
        return Number.isFinite(number) ? `${Math.round(number)}%` : "?%"
    }

    function signedPercentText(value) {
        const number = Number(value)
        if (!Number.isFinite(number)) return "?%"
        const rounded = Math.round(number)
        return `${rounded > 0 ? "+" : ""}${rounded}%`
    }

    function rateText(value) {
        const number = Number(value)
        if (!Number.isFinite(number)) return "?%/h"
        return `${number > 0 ? "+" : ""}${number.toFixed(2)}%/h`
    }

    function usageColor(value) {
        const number = Number(value)
        if (!Number.isFinite(number)) return Theme.surfaceText
        const clamped = Math.max(0, Math.min(100, number)) / 100
        const hue = 0.33 * (1 - clamped)
        return Qt.hsva(hue, 0.75, 0.9, 1)
    }

    function formatDuration(ms) {
        if (!Number.isFinite(ms) || ms <= 0) return ms <= 0 ? "now" : "?"
        let totalMinutes = Math.ceil(ms / 60000)
        const days = Math.floor(totalMinutes / (60 * 24))
        totalMinutes -= days * 60 * 24
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (days > 0) return hours > 0 ? `${days}d ${hours}h` : `${days}d`
        if (hours > 0) return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`
        return `${minutes}m`
    }

    function formatAge(ms) {
        if (!Number.isFinite(ms) || ms <= 0) return ms <= 0 ? "now" : "?"
        const totalSeconds = Math.floor(ms / 1000)
        if (totalSeconds < 60) return `${totalSeconds}s`
        const totalMinutes = Math.floor(totalSeconds / 60)
        if (totalMinutes < 60) return `${totalMinutes}m`
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours < 24) return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`
        const days = Math.floor(hours / 24)
        return days > 0 ? `${days}d` : "?"
    }

    function timeToResetText(isoString) {
        if (!isoString) return "?"
        const resetMs = Date.parse(isoString)
        return Number.isFinite(resetMs) ? formatDuration(resetMs - Date.now()) : "?"
    }

    function hoursUntil(isoString) {
        if (!isoString) return NaN
        const resetMs = Date.parse(isoString)
        return Number.isFinite(resetMs) ? Math.max(0, (resetMs - Date.now()) / 3600000) : NaN
    }

    function formatLocalDateTime(isoString) {
        if (!isoString) return "?"
        const date = new Date(isoString)
        if (isNaN(date.getTime())) return "?"
        const now = new Date()
        const sameDay = date.getFullYear() === now.getFullYear() &&
                        date.getMonth() === now.getMonth() &&
                        date.getDate() === now.getDate()
        const timeStr = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
        if (sameDay) return timeStr
        const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return `${weekdays[date.getDay()]} ${timeStr}`
    }

    function sessionTimeText(data) {
        return showAbsoluteTimes ? formatLocalDateTime(data.sessionResetsAt) : timeToResetText(data.sessionResetsAt)
    }

    function weeklyTimeText(data) {
        return showAbsoluteTimes ? formatLocalDateTime(data.weeklyResetsAt) : timeToResetText(data.weeklyResetsAt)
    }

    function expectedHourlyRate() {
        return 100 / (7 * 24)
    }

    function weeklyMetrics(data) {
        const used = Number(data.weeklyUsedPercent)
        const hoursRemaining = hoursUntil(data.weeklyResetsAt)
        const expectedRate = expectedHourlyRate()

        if (!Number.isFinite(used) || !Number.isFinite(hoursRemaining)) {
            return { actualUsage: NaN, expectedUsage: NaN, differenceFromExpected: NaN,
                     remainingAllowance: NaN, hoursRemaining: NaN, requiredRate: NaN,
                     expectedRate: expectedRate, observedRate: NaN, observedDepleteHours: NaN,
                     depletesBeforeReset: false, gapAfterDepletionHours: NaN }
        }

        const cycleHours = 7 * 24
        const elapsedHours = Math.max(0, cycleHours - hoursRemaining)
        const expectedUsage = Math.max(0, Math.min(100, elapsedHours * expectedRate))
        const differenceFromExpected = used - expectedUsage
        const remainingAllowance = Math.max(0, 100 - used)
        const requiredRate = hoursRemaining > 0 ? remainingAllowance / hoursRemaining : (remainingAllowance <= 0 ? 0 : NaN)
        const observedRate = elapsedHours > 0 ? used / elapsedHours : NaN

        let observedDepleteHours = NaN
        let depletesBeforeReset = false
        let gapAfterDepletionHours = NaN

        if (remainingAllowance <= 0) {
            observedDepleteHours = 0
            depletesBeforeReset = true
            gapAfterDepletionHours = hoursRemaining
        } else if (Number.isFinite(observedRate) && observedRate > 0) {
            observedDepleteHours = remainingAllowance / observedRate
            depletesBeforeReset = observedDepleteHours < hoursRemaining
            gapAfterDepletionHours = depletesBeforeReset ? (hoursRemaining - observedDepleteHours) : 0
        }

        return { actualUsage: used, expectedUsage, differenceFromExpected, remainingAllowance,
                 hoursRemaining, requiredRate, expectedRate, observedRate, observedDepleteHours,
                 depletesBeforeReset, gapAfterDepletionHours }
    }

    function depleteSummaryText(data) {
        const metrics = weeklyMetrics(data)
        if (!Number.isFinite(metrics.observedDepleteHours)) return "D ?"
        if (!metrics.depletesBeforeReset) return "D never"
        return `D ${formatDuration(metrics.observedDepleteHours * 3600000)}`
    }

    function deltaSummaryText(data) {
        const metrics = weeklyMetrics(data)
        if (!Number.isFinite(metrics.differenceFromExpected)) return "Δ ?"
        const rounded = Math.round(metrics.differenceFromExpected)
        return `Δ ${rounded > 0 ? "+" : ""}${rounded}`
    }

    function deltaSummaryColor(data) {
        const metrics = weeklyMetrics(data)
        if (!Number.isFinite(metrics.differenceFromExpected) || Math.round(metrics.differenceFromExpected) === 0)
            return Theme.surfaceVariantText
        return metrics.differenceFromExpected > 0 ? Theme.warning : Theme.primary
    }

    function depleteSummaryColor(data) {
        const metrics = weeklyMetrics(data)
        if (!Number.isFinite(metrics.observedDepleteHours)) return Theme.surfaceVariantText
        if (!metrics.depletesBeforeReset) return Theme.primary
        return usageColor(100)
    }

    function sessionSummary(data) {
        return `S: ${percentText(data.sessionUsedPercent)} ${sessionTimeText(data)}`
    }

    function lastRefreshText(data) {
        const updatedMs = Date.parse(data.updatedAt)
        return Number.isFinite(updatedMs) ? `${formatAge(Date.now() - updatedMs)} ago` : ""
    }

    // Codex parsing
    function parseCodexResponse(raw) {
        console.log("[AiUsage] Codex raw:", raw.substring(0, 200))
        const payload = JSON.parse(raw)
        if (!Array.isArray(payload) || payload.length === 0) throw new Error("No usage payload")

        const item = payload[0]
        const usage = item.usage || {}
        const primary = usage.primary || {}
        const secondary = usage.secondary || {}
        const identity = usage.identity || {}

        return {
            provider: "codex",
            userDisplay: identity.accountEmail || usage.accountEmail || "",
            sessionUsedPercent: Number(primary.usedPercent),
            sessionResetsAt: primary.resetsAt || "",
            weeklyUsedPercent: Number(secondary.usedPercent),
            weeklyResetsAt: secondary.resetsAt || "",
            updatedAt: usage.updatedAt || item.updatedAt || "",
            extra: { loginMethod: identity.loginMethod || usage.loginMethod || "" }
        }
    }

    // Kimi parsing
    function parseKimiResponse(raw) {
        console.log("[AiUsage] Kimi raw:", raw.substring(0, 200))
        const data = JSON.parse(raw)

        if (data.error) {
            throw new Error(`Kimi API: ${data.error.message || data.error.type || "Unknown error"}`)
        }

        const mainUsage = data.usage || {}
        const limits = data.limits || []
        const user = data.user || {}

        if (!data.usage || !data.limits) {
            throw new Error("Invalid response: missing usage or limits")
        }

        const weeklyLimit = Number(mainUsage.limit) || 0
        const weeklyUsed = Number(mainUsage.used) || 0
        const weeklyUsedPercent = weeklyLimit > 0 ? (weeklyUsed / weeklyLimit) * 100 : 0

        // Find shortest window limit for session
        let sessionLimit = 0, sessionUsed = 0, sessionResetsAt = "", sessionUsedPercent = 0
        if (limits.length > 0) {
            const sorted = limits.slice().sort((a, b) => (a.window?.duration || 0) - (b.window?.duration || 0))
            const shortest = sorted[0].detail || {}
            sessionLimit = Number(shortest.limit) || 0
            sessionUsed = Number(shortest.used) || 0
            sessionResetsAt = shortest.resetTime || ""
            sessionUsedPercent = sessionLimit > 0 ? (sessionUsed / sessionLimit) * 100 : 0
        }

        const parallel = data.parallel || {}
        const membership = user.membership?.level || ""

        return {
            provider: "kimi",
            userDisplay: user.userId || "",
            sessionUsedPercent: sessionUsedPercent,
            sessionResetsAt: sessionResetsAt,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyResetsAt: mainUsage.resetTime || "",
            updatedAt: new Date().toISOString(),
            extra: {
                membershipLevel: membership.replace("LEVEL_", ""),
                weeklyUsed: weeklyUsed,
                weeklyLimit: weeklyLimit,
                parallelActive: (parallel.details || []).length,
                parallelLimit: Number(parallel.limit) || 0
            }
        }
    }

    // Fetch functions
    function fetchCodex() {
        if (fetchCodexProcess.running) return
        codexData = mergeData(codexData, { loading: true, error: "" })
        fetchCodexProcess.running = true
    }

    function fetchKimi() {
        if (fetchKimiProcess.running) return
        kimiData = mergeData(kimiData, { loading: true, error: "" })
        fetchKimiProcess.running = true
    }

    function fetchUsage() {
        if (provider === "codex" || provider === "both") fetchCodex()
        if (provider === "kimi" || provider === "both") fetchKimi()
    }

    function toggleTimeDisplayMode() {
        pluginService?.savePluginData("aiUsage", "showAbsoluteTimes", !showAbsoluteTimes)
    }

    // Tooltip builders
    function buildTooltip(data, providerName) {
        const metrics = weeklyMetrics(data)
        const depleteText = metrics.depletesBeforeReset ?
            (showAbsoluteTimes ? formatLocalDateTime(new Date(Date.now() + metrics.observedDepleteHours * 3600000).toISOString())
                               : formatDuration(metrics.observedDepleteHours * 3600000))
            : "never before reset"
        const gapText = metrics.depletesBeforeReset && Number.isFinite(metrics.gapAfterDepletionHours)
            ? formatDuration(metrics.gapAfterDepletionHours * 3600000) : "none"
        const requiredDelta = Number.isFinite(metrics.requiredRate) && Number.isFinite(metrics.expectedRate)
            ? metrics.requiredRate - metrics.expectedRate : NaN

        let extraInfo = ""
        if (data.provider === "kimi" && data.extra) {
            extraInfo = `\n\nQuota: ${data.extra.weeklyUsed}/${data.extra.weeklyLimit}\nParallel: ${data.extra.parallelActive}/${data.extra.parallelLimit} active`
        }

        return `${providerName} usage${data.userDisplay ? `\n${data.userDisplay}` : ""}${data.extra?.membershipLevel ? ` (${data.extra.membershipLevel})` : ""}
Session: ${percentText(data.sessionUsedPercent)} used · resets ${showAbsoluteTimes ? "at" : "in"} ${sessionTimeText(data)}
Weekly: ${percentText(data.weeklyUsedPercent)} used · resets ${showAbsoluteTimes ? "at" : "in"} ${weeklyTimeText(data)}

Actual: ${percentText(metrics.actualUsage)} / Expected: ${percentText(metrics.expectedUsage)} / ${signedPercentText(metrics.differenceFromExpected)}

Required rate: ${rateText(metrics.requiredRate)} · Expected: ${rateText(metrics.expectedRate)} · Diff: ${rateText(requiredDelta)}

Depletes ${showAbsoluteTimes ? "at" : "in"}: ${depleteText}
Gap before reset: ${gapText}${extraInfo}`
    }

    function tooltipText() {
        const parts = []
        if (provider === "codex" || provider === "both") {
            parts.push(buildTooltip(codexData, "Codex"))
        }
        if (provider === "kimi" || provider === "both") {
            if (parts.length > 0) parts.push("")
            parts.push(buildTooltip(kimiData, "Kimi"))
        }
        return parts.join("\n")
    }

    popoutWidth: 460
    popoutHeight: provider === "both" ? 480 : 280

    popoutContent: Component {
        Rectangle {
            color: Theme.surface
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.outlineMedium

            Column {
                id: headerColumn
                x: Theme.spacingM
                y: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingS

                StyledText {
                    text: "AI Usage"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Repeater {
                    model: root.getActiveProviders()
                    delegate: Rectangle {
                        visible: modelData.data.error.length === 0
                        width: parent.width
                        height: col.implicitHeight + Theme.spacingM * 2
                        color: Theme.surfaceVariant
                        radius: Theme.cornerRadius

                        Column {
                            id: col
                            x: Theme.spacingM
                            y: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            spacing: Theme.spacingXS

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                visible: modelData.data.error.length === 0 && modelData.data.userDisplay
                                text: modelData.data.userDisplay + (modelData.data.extra?.membershipLevel ? ` (${modelData.data.extra.membershipLevel})` : "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                visible: modelData.data.error.length === 0
                                text: `Session: ${root.percentText(modelData.data.sessionUsedPercent)} used · resets ${root.showAbsoluteTimes ? "at" : "in"} ${root.sessionTimeText(modelData.data)}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                visible: modelData.data.error.length === 0 && modelData.data.provider === "kimi"
                                text: modelData.data.extra ? `Quota: ${modelData.data.extra.weeklyUsed}/${modelData.data.extra.weeklyLimit} · Parallel: ${modelData.data.extra.parallelActive}/${modelData.data.extra.parallelLimit}` : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                visible: modelData.data.error.length > 0
                                text: modelData.data.error
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                            }
                        }
                    }
                }
            }

            DankFlickable {
                x: Theme.spacingM
                y: headerColumn.y + headerColumn.implicitHeight + Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                height: parent.height - y - Theme.spacingM
                clip: true

                StyledText {
                    width: parent.width
                    text: root.tooltipText()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // Processes
    Process {
        id: fetchCodexProcess
        running: false
        command: ["codexbar", "--provider", "codex", "--source", "cli", "--format", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = root.parseCodexResponse(text.trim())
                    root.codexData = mergeData(parsed, { loading: false, error: "" })
                } catch (e) {
                    console.warn("[AiUsage] Codex parse error:", e)
                    root.codexData = mergeData(root.codexData, { loading: false, error: "Parse failed" })
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.codexData = mergeData(root.codexData, { loading: false, error: "Fetch failed" })
            }
        }
    }

    Process {
        id: fetchKimiProcess
        running: false
        command: ["sh", "-c", "KEY=$(python3 -c 'import json, os; p=os.path.expanduser(\"~/.pi/agent/auth.json\"); d=json.load(open(p)); print(d.get(\"kimi-coding\", {}).get(\"key\", \"\"))' 2>/dev/null); if [ -z \"$KEY\" ]; then echo '{\"error\":{\"message\":\"Missing kimi-coding key in ~/.pi/agent/auth.json\"}}'; else curl -s -H \"Authorization: Bearer $KEY\" https://api.kimi.com/coding/v1/usages; fi" ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = root.parseKimiResponse(text.trim())
                    root.kimiData = mergeData(parsed, { loading: false, error: "" })
                } catch (e) {
                    console.warn("[AiUsage] Kimi parse error:", e)
                    root.kimiData = mergeData(root.kimiData, { loading: false, error: e.message || "Parse failed" })
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.kimiData = mergeData(root.kimiData, { loading: false, error: "Fetch failed" })
            }
        }
    }

    Timer {
        interval: Math.max(30, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        onTriggered: root.fetchUsage()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.clockTicker++
    }

    Component.onCompleted: fetchUsage()
    onRefreshIntervalSecChanged: fetchUsage()
    onProviderChanged: fetchUsage()

    pillRightClickAction: () => toggleTimeDisplayMode()

    // Shared UI component
    component UsagePill: Row {
        property var usageData
        property string providerName

        spacing: Theme.spacingXS

        StyledText {
            text: providerName + ":"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: usageData.loading && usageData.error.length === 0 && usageData.sessionUsedPercent < 0
            text: "…"
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: !usageData.loading && usageData.error.length > 0
            text: usageData.error
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            visible: usageData.error.length === 0 && usageData.sessionUsedPercent >= 0
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.sessionSummary(usageData)
                font.pixelSize: Theme.fontSizeSmall
                color: root.usageColor(usageData.sessionUsedPercent)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "·"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: `W: ${root.percentText(usageData.weeklyUsedPercent)} ${root.weeklyTimeText(usageData)}`
                font.pixelSize: Theme.fontSizeSmall
                color: root.usageColor(usageData.weeklyUsedPercent)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "·"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.deltaSummaryText(usageData)
                font.pixelSize: Theme.fontSizeSmall
                color: root.deltaSummaryColor(usageData)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "·"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.depleteSummaryText(usageData)
                font.pixelSize: Theme.fontSizeSmall
                color: root.depleteSummaryColor(usageData)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.lastRefreshText(usageData).length > 0
                text: "· " + root.lastRefreshText(usageData)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingM
            Repeater {
                model: root.getActiveProviders()
                delegate: UsagePill {
                    usageData: modelData.data
                    providerName: modelData.name
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingS
            Repeater {
                model: root.getActiveProviders()
                delegate: Column {
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: modelData.data.loading && modelData.data.error.length === 0 && modelData.data.sessionUsedPercent < 0
                        text: "…"
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: !modelData.data.loading && modelData.data.error.length > 0
                        text: modelData.data.error
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Column {
                        visible: modelData.data.error.length === 0 && modelData.data.sessionUsedPercent >= 0
                        spacing: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledText {
                            text: root.sessionSummary(modelData.data)
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.usageColor(modelData.data.sessionUsedPercent)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.horizontalCenter: parent.horizontalCenter

                            StyledText {
                                text: `W: ${root.percentText(modelData.data.weeklyUsedPercent)} ${root.weeklyTimeText(modelData.data)}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.usageColor(modelData.data.weeklyUsedPercent)
                            }

                            StyledText {
                                text: "·"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.deltaSummaryText(modelData.data)
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.deltaSummaryColor(modelData.data)
                            }

                            StyledText {
                                text: "·"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.depleteSummaryText(modelData.data)
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.depleteSummaryColor(modelData.data)
                            }
                        }

                        StyledText {
                            visible: root.lastRefreshText(modelData.data).length > 0
                            text: root.lastRefreshText(modelData.data)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
