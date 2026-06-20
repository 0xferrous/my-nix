import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root

    property string text: ""
    property int maxWidth: 460
    property int popupHeight: 220
    readonly property bool visible: tooltip.visible

    function show(text, item, offsetX, offsetY, preferredSide) {
        if (!item)
            return

        let windowContentItem = item.Window?.window?.contentItem
        if (!windowContentItem) {
            let current = item
            while (current) {
                if (current.Window?.window?.contentItem) {
                    windowContentItem = current.Window.window.contentItem
                    break
                }
                current = current.parent
            }
        }
        if (!windowContentItem)
            return

        tooltip.parent = windowContentItem
        root.text = text

        const itemPos = item.mapToItem(windowContentItem, 0, 0)
        const parentWidth = windowContentItem.width
        const parentHeight = windowContentItem.height
        const tooltipWidth = tooltip.width
        const tooltipHeight = tooltip.height
        const side = preferredSide || _determineBestSide(itemPos, item, parentWidth, parentHeight, tooltipWidth, tooltipHeight)

        let targetX = 0
        let targetY = 0

        switch (side) {
        case "left":
            targetX = itemPos.x - tooltipWidth - 8
            targetY = itemPos.y + (item.height - tooltipHeight) / 2
            break
        case "right":
            targetX = itemPos.x + item.width + 8
            targetY = itemPos.y + (item.height - tooltipHeight) / 2
            break
        case "top":
            targetX = itemPos.x + (item.width - tooltipWidth) / 2
            targetY = itemPos.y - tooltipHeight - 8
            break
        case "bottom":
        default:
            targetX = itemPos.x + (item.width - tooltipWidth) / 2
            targetY = itemPos.y + item.height + 8
            break
        }

        tooltip.x = Math.max(4, Math.min(parentWidth - tooltipWidth - 4, targetX + (offsetX || 0)))
        tooltip.y = Math.max(4, Math.min(parentHeight - tooltipHeight - 4, targetY + (offsetY || 0)))
        tooltip.visible = true
    }

    function hide() {
        tooltip.visible = false
    }

    function toggle(text, item, offsetX, offsetY, preferredSide) {
        if (tooltip.visible)
            hide()
        else
            show(text, item, offsetX, offsetY, preferredSide)
    }

    function _determineBestSide(itemPos, item, parentWidth, parentHeight, tooltipWidth, tooltipHeight) {
        const itemCenterX = itemPos.x + item.width / 2
        const spaceLeft = itemPos.x
        const spaceRight = parentWidth - (itemPos.x + item.width)
        const spaceTop = itemPos.y
        const spaceBottom = parentHeight - (itemPos.y + item.height)

        if (spaceTop >= tooltipHeight + 16)
            return "top"
        if (spaceBottom >= tooltipHeight + 16)
            return "bottom"
        if (spaceRight >= tooltipWidth + 16)
            return "right"
        if (spaceLeft >= tooltipWidth + 16)
            return "left"

        if (itemCenterX > parentWidth / 2)
            return "left"
        return "right"
    }

    Popup {
        id: tooltip

        leftPadding: Theme.spacingM
        rightPadding: Theme.spacingM
        topPadding: Theme.spacingS
        bottomPadding: Theme.spacingS
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: false
        dim: false
        focus: true
        width: root.maxWidth
        height: root.popupHeight

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.outlineMedium
        }

        contentItem: Flickable {
            id: flick
            clip: true
            contentWidth: width
            contentHeight: popupText.contentHeight
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: popupText
                width: flick.width
                text: root.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.Wrap
            }
        }
    }
}
