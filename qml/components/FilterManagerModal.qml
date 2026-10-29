import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: filterModal
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.70)
    visible: false
    z: 110

    property var relayController
    property var theme
    property bool saveNoticeActive: false
    property string toastText: ""
    property int filtersVersion: 0
    property int currentTab: 0 // 0: Active Filters, 1: Preset Templates, 2: Custom Filter

    onVisibleChanged: {
        if (visible && relayController) {
            relayController.request_filters()
        }
    }

    Connections {
        target: relayController
        function onFilters_changed() {
            filterModal.filtersVersion++
        }
    }

    function isFilterInstalled(name) {
        var dummy = filterModal.filtersVersion
        return relayController ? relayController.has_filter(name) : false
    }

    function isFilterActive(name) {
        var dummy = filterModal.filtersVersion
        return relayController ? relayController.is_filter_enabled(name) : false
    }

    function getFilterCategory(name, tags) {
        if (name === "irc_smart_filter" || tags === "irc_smart_filter") return "Smart Filter"
        if (name.startsWith("mute_") || tags.indexOf("nick_") !== -1) return "Muted Nick"
        if (name === "join_part_quit") return "Joins & Parts"
        if (name === "nick_changes") return "Nick Changes"
        if (name === "channel_modes") return "Modes & Bans"
        if (name === "topic_changes") return "Topic Notices"
        if (name === "service_bots") return "Service Bots"
        return "Custom Rule"
    }

    function getFilterIcon(name, tags) {
        if (name === "irc_smart_filter" || tags === "irc_smart_filter") return "🛡️"
        if (name.startsWith("mute_") || tags.indexOf("nick_") !== -1) return "🔇"
        if (name === "join_part_quit") return "🚪"
        if (name === "nick_changes") return "🏷️"
        if (name === "channel_modes") return "🔧"
        if (name === "topic_changes") return "📢"
        if (name === "service_bots") return "🤖"
        return "⚙️"
    }

    function showToast(msg) {
        filterModal.toastText = msg
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 3500
        repeat: false
        onTriggered: filterModal.toastText = ""
    }

    Timer {
        id: saveNoticeTimer
        interval: 2500
        repeat: false
        onTriggered: filterModal.saveNoticeActive = false
    }

    // Modern Switch Component (100% responsive, instant feedback, no snap-back)
    component ModernSwitch: Rectangle {
        id: swRoot
        property bool checked: false
        signal toggled(bool newState)

        width: 44
        height: 24
        radius: 12
        color: checked ? theme.accentPrimary : theme.bgElevated
        border.color: checked ? theme.accentPrimary : theme.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: swThumb
            width: 18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: swRoot.checked ? (swRoot.width - width - 3) : 3
            color: swRoot.checked ? theme.bgPrimary : theme.textSecondary

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        HoverHandler { id: swHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                swRoot.toggled(!swRoot.checked)
            }
        }
    }

    // Inline Preset Card Helper Component (TEMPLATE CARD with Add / Installed button, NO SWITCH)
    component FilterTemplateCard: Rectangle {
        id: templateCardRoot
        property var theme
        property string iconText: ""
        property string title: ""
        property string description: ""
        property string presetKey: ""
        property string filterName: ""
        property string tagsSummary: ""
        property bool isInstalled: false
        signal addRequested()
        signal viewRequested()

        height: 106
        radius: 11
        color: isInstalled
            ? Qt.alpha(theme.accentPrimary, 0.08)
            : (cardHover.hovered ? theme.bgHover : theme.bgSecondary)
        border.color: isInstalled
            ? Qt.alpha(theme.accentPrimary, 0.40)
            : (cardHover.hovered ? theme.borderFocus : theme.borderSubtle)
        border.width: 1

        HoverHandler { id: cardHover }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                width: 42
                height: 42
                radius: 10
                color: isInstalled ? Qt.alpha(theme.accentPrimary, 0.22) : theme.bgElevated

                Text {
                    anchors.centerIn: parent
                    text: iconText
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: title
                    color: theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: description
                    color: theme.textSecondary
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "tags: " + tagsSummary
                    color: theme.textMuted
                    font.pixelSize: 10
                    font.family: theme.fontMono
                }
            }

            // Action Button: Clear "Added to Filters" or "Add Preset"
            Rectangle {
                height: 34
                radius: 7
                implicitWidth: actionBtnTxt.implicitWidth + 24
                color: isInstalled
                    ? theme.bgElevated
                    : (actHover.hovered ? theme.accentHover : theme.accentPrimary)
                border.color: isInstalled ? theme.borderSubtle : theme.accentPrimary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: isInstalled ? "✓" : "+"
                        color: isInstalled ? theme.statusOnline : theme.bgPrimary
                        font.bold: true
                        font.pixelSize: 12
                    }

                    Text {
                        id: actionBtnTxt
                        text: isInstalled ? "Added to Filters" : "Add Preset"
                        color: isInstalled ? theme.textPrimary : theme.bgPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                HoverHandler { id: actHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (isInstalled) {
                            templateCardRoot.viewRequested()
                        } else {
                            templateCardRoot.addRequested()
                        }
                    }
                }
            }
        }
    }

    // Inline Tag Chip Helper Component
    component FilterTagChip: Rectangle {
        property string tagLabel: ""
        property string tagCode: ""
        property var targetInput
        property var theme

        height: 28
        radius: 7
        implicitWidth: chipTxt.implicitWidth + 16
        color: chipHover.hovered ? theme.bgHover : theme.bgElevated
        border.color: theme.borderSubtle

        Text {
            id: chipTxt
            anchors.centerIn: parent
            text: "+ " + tagLabel
            color: chipHover.hovered ? theme.accentCyan : theme.textSecondary
            font.pixelSize: 11
            font.bold: true
        }

        HoverHandler { id: chipHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!targetInput) return
                var cur = targetInput.text.trim()
                if (cur.length === 0 || cur === "*") {
                    targetInput.text = tagCode
                } else {
                    var parts = cur.split(",")
                    if (parts.indexOf(tagCode) === -1) {
                        targetInput.text = cur + "," + tagCode
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: filterModal.visible = false
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 64, 860)
        height: Math.min(parent.height - 64, 760)
        anchors.centerIn: parent
        radius: 16
        color: theme.bgElevated
        border.color: theme.borderSubtle
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        // Top-Right Close Button
        Rectangle {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 18
            anchors.rightMargin: 18
            width: 34
            height: 34
            radius: 8
            z: 20
            color: closeHover.hovered ? theme.bgHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeHover.hovered ? theme.textPrimary : theme.textSecondary
                font.pixelSize: 15
                font.bold: true
            }

            HoverHandler { id: closeHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: filterModal.visible = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 40
                spacing: 16

                Rectangle {
                    width: 42
                    height: 42
                    radius: 11
                    color: Qt.alpha(theme.accentCyan, 0.22)
                    border.color: theme.accentCyan
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⛯"
                        color: theme.accentCyan
                        font.pixelSize: 22
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 10
                        Text {
                            text: "Event & Message Filters"
                            color: theme.textPrimary
                            font.pixelSize: 19
                            font.bold: true
                        }

                        Rectangle {
                            height: 22
                            radius: 11
                            implicitWidth: filterBadgeTxt.implicitWidth + 16
                            color: relayController.active_filter_count > 0 ? Qt.alpha(theme.accentCyan, 0.20) : theme.bgSecondary
                            border.color: relayController.active_filter_count > 0 ? theme.accentCyan : theme.borderSubtle

                            Text {
                                id: filterBadgeTxt
                                anchors.centerIn: parent
                                text: relayController.active_filter_count + " Active"
                                color: relayController.active_filter_count > 0 ? theme.accentCyan : theme.textMuted
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        text: "Manage WeeChat server-side message filters (/filter). Hidden messages stay preserved in backlog history."
                        color: theme.textSecondary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // 💾 Save to WeeChat Button
                Rectangle {
                    height: 38
                    radius: 8
                    implicitWidth: saveBtnContent.implicitWidth + 28
                    color: filterModal.saveNoticeActive
                        ? theme.statusOnline
                        : (saveBtnHover.hovered ? theme.bgHover : theme.bgSecondary)
                    border.color: filterModal.saveNoticeActive ? theme.statusOnline : theme.borderSubtle
                    border.width: 1

                    RowLayout {
                        id: saveBtnContent
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: filterModal.saveNoticeActive ? "✓" : "💾"
                            color: filterModal.saveNoticeActive ? theme.bgPrimary : theme.accentCyan
                            font.pixelSize: 14
                        }

                        Text {
                            text: filterModal.saveNoticeActive ? "Saved to WeeChat!" : "Save (/save)"
                            color: filterModal.saveNoticeActive ? theme.bgPrimary : theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    HoverHandler { id: saveBtnHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            relayController.save_weechat_config()
                            filterModal.saveNoticeActive = true
                            saveNoticeTimer.restart()
                        }
                    }
                }
            }

            // Master Filter Engine Toggle Row (Alt+=)
            Rectangle {
                Layout.fillWidth: true
                height: 54
                radius: 11
                color: theme.bgSecondary
                border.color: relayController.filters_global_enabled ? Qt.alpha(theme.accentPrimary, 0.45) : theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: relayController.filters_global_enabled ? Qt.alpha(theme.accentPrimary, 0.25) : theme.bgElevated

                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            color: relayController.filters_global_enabled ? theme.accentPrimary : theme.textMuted
                            font.pixelSize: 15
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 10
                            Text {
                                text: "Master Filter Engine (Alt+=)"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Rectangle {
                                height: 18
                                radius: 9
                                implicitWidth: statusTxt.implicitWidth + 12
                                color: relayController.filters_global_enabled ? Qt.alpha(theme.statusOnline, 0.20) : Qt.alpha(theme.statusWarning, 0.20)
                                border.color: relayController.filters_global_enabled ? theme.statusOnline : theme.statusWarning

                                Text {
                                    id: statusTxt
                                    anchors.centerIn: parent
                                    text: relayController.filters_global_enabled ? "RUNNING" : "BYPASSED (SHOWING ALL)"
                                    color: relayController.filters_global_enabled ? theme.statusOnline : theme.statusWarning
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: relayController.filters_global_enabled
                                ? "Filters are actively suppressing noise"
                                : "All filters bypassed; raw messages and notices are visible"
                            color: theme.textSecondary
                            font.pixelSize: 11
                        }
                    }

                    ModernSwitch {
                        checked: relayController.filters_global_enabled
                        onToggled: relayController.toggle_all_filters()
                    }
                }
            }

            // Toast feedback banner (if any)
            Rectangle {
                Layout.fillWidth: true
                height: filterModal.toastText.length > 0 ? 36 : 0
                visible: filterModal.toastText.length > 0
                radius: 8
                color: Qt.alpha(theme.accentCyan, 0.15)
                border.color: theme.accentCyan
                border.width: 1
                clip: true

                Behavior on height { NumberAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text { text: "✓"; color: theme.accentCyan; font.bold: true; font.pixelSize: 13 }
                    Text {
                        text: filterModal.toastText
                        color: theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "View Active Filters →"
                        color: theme.accentCyan
                        font.pixelSize: 12
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filterModal.currentTab = 0
                        }
                    }
                }
            }

            // Segmented Navigation Tabs
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 10
                color: theme.bgSecondary
                border.color: theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    // Tab 0: Active Filters
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 8
                        color: filterModal.currentTab === 0 ? theme.bgActive : "transparent"
                        border.color: filterModal.currentTab === 0 ? theme.accentCyan : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "📋  Active Filters (" + relayController.filter_model.rowCount + ")"
                            color: filterModal.currentTab === 0 ? theme.textPrimary : theme.textSecondary
                            font.pixelSize: 12
                            font.bold: filterModal.currentTab === 0
                            font.family: theme.fontSans
                        }

                        HoverHandler { id: tab0Hover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filterModal.currentTab = 0
                        }
                    }

                    // Tab 1: Preset Templates
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 8
                        color: filterModal.currentTab === 1 ? theme.bgActive : "transparent"
                        border.color: filterModal.currentTab === 1 ? theme.accentCyan : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "⚡  Preset Templates (6)"
                            color: filterModal.currentTab === 1 ? theme.textPrimary : theme.textSecondary
                            font.pixelSize: 12
                            font.bold: filterModal.currentTab === 1
                            font.family: theme.fontSans
                        }

                        HoverHandler { id: tab1Hover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filterModal.currentTab = 1
                        }
                    }

                    // Tab 2: Custom Filter
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 8
                        color: filterModal.currentTab === 2 ? theme.bgActive : "transparent"
                        border.color: filterModal.currentTab === 2 ? theme.accentCyan : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "🛠️  Custom Filter"
                            color: filterModal.currentTab === 2 ? theme.textPrimary : theme.textSecondary
                            font.pixelSize: 12
                            font.bold: filterModal.currentTab === 2
                            font.family: theme.fontSans
                        }

                        HoverHandler { id: tab2Hover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filterModal.currentTab = 2
                        }
                    }
                }
            }

            // Main Tab View Area
            StackLayout {
                id: mainStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: filterModal.currentTab

                // ==========================================
                // VIEW 0: ACTIVE FILTERS (HERO SECTION)
                // ==========================================
                ColumnLayout {
                    id: activeFiltersView
                    spacing: 10

                    // Active Filters Sub-header & Controls Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "CONFIGURED FILTERS"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Text {
                            text: "— Click toggle to enable or pause filter"
                            color: theme.textMuted
                            font.pixelSize: 11
                        }

                        Item { Layout.fillWidth: true }

                        // Refresh list button
                        Rectangle {
                            height: 30
                            radius: 7
                            implicitWidth: refreshRow.implicitWidth + 18
                            color: refHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                id: refreshRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "⟳"; color: theme.textSecondary; font.pixelSize: 12 }
                                Text { text: "Refresh"; color: theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            }

                            HoverHandler { id: refHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.request_filters()
                            }
                        }

                        // Quick Add Button
                        Rectangle {
                            height: 30
                            radius: 7
                            implicitWidth: addQuickRow.implicitWidth + 18
                            color: addQuickHover.hovered ? theme.accentHover : theme.accentPrimary

                            RowLayout {
                                id: addQuickRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "+"; color: theme.bgPrimary; font.bold: true; font.pixelSize: 13 }
                                Text { text: "Add Filter"; color: theme.bgPrimary; font.bold: true; font.pixelSize: 11 }
                            }

                            HoverHandler { id: addQuickHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: filterModal.currentTab = 1
                            }
                        }
                    }

                    // Search / Filter Input
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: theme.bgInput
                        border.color: searchFiltersInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                        visible: relayController.filter_model.rowCount > 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text { text: "🔍"; font.pixelSize: 12; color: theme.textMuted }
                            TextInput {
                                id: searchFiltersInput
                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.textPrimary
                                font.pixelSize: 12
                                font.family: theme.fontSans
                                selectByMouse: true
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "Search filters by name, tag, or buffer scope..."
                                color: theme.textMuted
                                font.pixelSize: 12
                                visible: searchFiltersInput.text.length === 0 && !searchFiltersInput.activeFocus
                            }
                            Text {
                                text: "✕"
                                color: theme.textMuted
                                font.pixelSize: 12
                                visible: searchFiltersInput.text.length > 0
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchFiltersInput.text = ""
                                }
                            }
                        }
                    }

                    // Scrollable List of Active Filters
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            id: activeListContainer
                            width: parent.width
                            implicitHeight: activeFiltersCol.implicitHeight + 20

                            ColumnLayout {
                                id: activeFiltersCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 12
                                spacing: 10

                                // Empty State Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 190
                                    radius: 12
                                    color: theme.bgSecondary
                                    border.color: theme.borderSubtle
                                    visible: relayController.filter_model.rowCount === 0

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 12
                                        Layout.alignment: Qt.AlignHCenter

                                        Text {
                                            text: "⚡"
                                            font.pixelSize: 32
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: "No WeeChat filters configured yet"
                                            color: theme.textPrimary
                                            font.pixelSize: 15
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: "Filters eliminate background noise like join/parts, mute bots, or silence specific users."
                                            color: theme.textSecondary
                                            font.pixelSize: 12
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        RowLayout {
                                            spacing: 12
                                            Layout.alignment: Qt.AlignHCenter

                                            Rectangle {
                                                height: 36
                                                radius: 8
                                                implicitWidth: browsePresetBtnTxt.implicitWidth + 24
                                                color: bpbtnHover.hovered ? theme.accentHover : theme.accentPrimary

                                                Text {
                                                    id: browsePresetBtnTxt
                                                    anchors.centerIn: parent
                                                    text: "⚡ Choose from Presets"
                                                    color: theme.bgPrimary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                HoverHandler { id: bpbtnHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: filterModal.currentTab = 1
                                                }
                                            }

                                            Rectangle {
                                                height: 36
                                                radius: 8
                                                implicitWidth: custBtnTxt.implicitWidth + 24
                                                color: cbtnHover.hovered ? theme.bgHover : theme.bgElevated
                                                border.color: theme.borderSubtle

                                                Text {
                                                    id: custBtnTxt
                                                    anchors.centerIn: parent
                                                    text: "🛠️ Create Custom Filter"
                                                    color: theme.textPrimary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }

                                                HoverHandler { id: cbtnHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: filterModal.currentTab = 2
                                                }
                                            }
                                        }
                                    }
                                }

                                // List of Active Filters
                                Repeater {
                                    model: relayController.filter_model
                                    delegate: Rectangle {
                                        id: filterRowRoot
                                        property bool matchesSearch: searchFiltersInput.text.length === 0
                                            || model.name.toLowerCase().indexOf(searchFiltersInput.text.toLowerCase()) !== -1
                                            || model.tags.toLowerCase().indexOf(searchFiltersInput.text.toLowerCase()) !== -1
                                            || model.buffer.toLowerCase().indexOf(searchFiltersInput.text.toLowerCase()) !== -1

                                        visible: matchesSearch
                                        Layout.fillWidth: true
                                        height: visible ? implicitHeight : 0
                                        implicitHeight: 72
                                        radius: 10
                                        color: model.enabled
                                            ? Qt.alpha(theme.accentPrimary, 0.08)
                                            : (filterRowHover.hovered ? theme.bgHover : theme.bgSecondary)
                                        border.color: model.enabled ? Qt.alpha(theme.accentPrimary, 0.35) : theme.borderSubtle
                                        border.width: 1

                                        HoverHandler { id: filterRowHover }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            spacing: 14

                                            // Authoritative, Custom-Engineered Switch (Zero snap-back)
                                            ModernSwitch {
                                                checked: model.enabled
                                                onToggled: relayController.toggle_weechat_filter(model.name)
                                            }

                                            // Category Icon Badge
                                            Rectangle {
                                                width: 38
                                                height: 38
                                                radius: 9
                                                color: model.enabled ? Qt.alpha(theme.accentPrimary, 0.22) : theme.bgElevated

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: filterModal.getFilterIcon(model.name, model.tags)
                                                    font.pixelSize: 16
                                                }
                                            }

                                            // Filter Info Column
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 4

                                                RowLayout {
                                                    spacing: 10
                                                    Text {
                                                        text: model.name
                                                        color: theme.textPrimary
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        font.family: theme.fontMono
                                                        elide: Text.ElideRight
                                                    }

                                                    // Type Badge
                                                    Rectangle {
                                                        height: 20
                                                        radius: 5
                                                        implicitWidth: typeTxt.implicitWidth + 10
                                                        color: theme.bgElevated
                                                        border.color: theme.borderSubtle

                                                        Text {
                                                            id: typeTxt
                                                            anchors.centerIn: parent
                                                            text: filterModal.getFilterCategory(model.name, model.tags)
                                                            color: theme.accentCyan
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                        }
                                                    }

                                                    // Status Tag (ENABLED / PAUSED)
                                                    Rectangle {
                                                        height: 20
                                                        radius: 5
                                                        implicitWidth: stTagTxt.implicitWidth + 10
                                                        color: model.enabled ? Qt.alpha(theme.statusOnline, 0.18) : Qt.alpha(theme.textMuted, 0.18)
                                                        border.color: model.enabled ? theme.statusOnline : theme.borderSubtle

                                                        Text {
                                                            id: stTagTxt
                                                            anchors.centerIn: parent
                                                            text: model.enabled ? "ENABLED" : "PAUSED"
                                                            color: model.enabled ? theme.statusOnline : theme.textMuted
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                        }
                                                    }
                                                }

                                                // Details chips (Scope, Tags, Regex) with generous padding
                                                RowLayout {
                                                    spacing: 8
                                                    Layout.fillWidth: true

                                                    Rectangle {
                                                        height: 20
                                                        radius: 4
                                                        implicitWidth: scChipTxt.implicitWidth + 10
                                                        color: theme.bgElevated
                                                        Text {
                                                            id: scChipTxt
                                                            anchors.centerIn: parent
                                                            text: "Scope: " + (model.buffer === "*" ? "Global (*)" : model.buffer)
                                                            color: theme.textSecondary
                                                            font.pixelSize: 10
                                                            font.family: theme.fontMono
                                                        }
                                                    }

                                                    Rectangle {
                                                        height: 20
                                                        radius: 4
                                                        implicitWidth: tagChipTxt.implicitWidth + 10
                                                        color: theme.bgElevated
                                                        Text {
                                                            id: tagChipTxt
                                                            anchors.centerIn: parent
                                                            text: "Tags: " + model.tags
                                                            color: theme.textSecondary
                                                            font.pixelSize: 10
                                                            font.family: theme.fontMono
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    Rectangle {
                                                        height: 20
                                                        radius: 4
                                                        implicitWidth: regChipTxt.implicitWidth + 10
                                                        color: theme.bgElevated
                                                        Text {
                                                            id: regChipTxt
                                                            anchors.centerIn: parent
                                                            text: "Pattern: " + (model.regex === "*" ? "any (*)" : model.regex)
                                                            color: theme.textMuted
                                                            font.pixelSize: 10
                                                            font.family: theme.fontMono
                                                        }
                                                    }

                                                    Item { Layout.fillWidth: true }
                                                }
                                            }

                                            // Delete Button
                                            Rectangle {
                                                width: 34
                                                height: 34
                                                radius: 8
                                                color: delHover.hovered ? Qt.alpha(theme.statusError, 0.25) : "transparent"
                                                border.color: delHover.hovered ? theme.statusError : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "🗑"
                                                    color: delHover.hovered ? theme.statusError : theme.textMuted
                                                    font.pixelSize: 14
                                                }

                                                HoverHandler { id: delHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: relayController.delete_weechat_filter(model.name)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // VIEW 1: PRESET TEMPLATES
                // ==========================================
                ColumnLayout {
                    id: presetsView
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "POPULAR IRC PRESETS"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Text {
                            text: "— Common IRC filter templates ready to install into your Active Filters."
                            color: theme.textMuted
                            font.pixelSize: 11
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            width: parent.width
                            implicitHeight: presetsGrid.implicitHeight + 24

                            GridLayout {
                                id: presetsGrid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 12
                                columns: 2
                                columnSpacing: 14
                                rowSpacing: 14

                                // Preset 1: Smart Filter
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "🛡️"
                                    title: "Smart Filter (Recommended)"
                                    description: "Hide idle lurkers; only show join/part events for users who spoke in the last 30 minutes. Auto-enables irc.look.smart_filter."
                                    presetKey: "smart_filter"
                                    filterName: "irc_smart_filter"
                                    tagsSummary: "irc_smart_filter"
                                    isInstalled: filterModal.isFilterInstalled("irc_smart_filter")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("smart_filter")
                                        filterModal.showToast("Added 'Smart Filter' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 2: Join / Part / Quit Silence
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "🚪"
                                    title: "All Joins, Parts & Quits"
                                    description: "Completely silence all channel entry, departure, and quit notices across all channels to eliminate busy-room flood."
                                    presetKey: "join_part_quit"
                                    filterName: "join_part_quit"
                                    tagsSummary: "irc_join,irc_part,irc_quit"
                                    isInstalled: filterModal.isFilterInstalled("join_part_quit")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("join_part_quit")
                                        filterModal.showToast("Added 'All Joins, Parts & Quits' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 3: Nick Changes
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "🏷️"
                                    title: "Nickname Changes"
                                    description: "Hide user rename announcements (e.g. Alice is now known as Alice|Away) to keep chat streams clean."
                                    presetKey: "nick_changes"
                                    filterName: "nick_changes"
                                    tagsSummary: "irc_nick"
                                    isInstalled: filterModal.isFilterInstalled("nick_changes")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("nick_changes")
                                        filterModal.showToast("Added 'Nickname Changes' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 4: Channel Modes & Bans
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "🔧"
                                    title: "Channel Modes & Bans"
                                    description: "Hide channel operator, voice, and ban alterations (+o, -v, +b, +q) during mass moderation or raids."
                                    presetKey: "channel_modes"
                                    filterName: "channel_modes"
                                    tagsSummary: "irc_mode"
                                    isInstalled: filterModal.isFilterInstalled("channel_modes")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("channel_modes")
                                        filterModal.showToast("Added 'Channel Modes & Bans' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 5: Topic Changes
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "📢"
                                    title: "Channel Topic Notices"
                                    description: "Hide in-feed topic modification lines since the current channel topic is already displayed in the top header."
                                    presetKey: "topic_changes"
                                    filterName: "topic_changes"
                                    tagsSummary: "irc_topic"
                                    isInstalled: filterModal.isFilterInstalled("topic_changes")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("topic_changes")
                                        filterModal.showToast("Added 'Channel Topic Notices' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 6: Service Bots
                                FilterTemplateCard {
                                    Layout.fillWidth: true
                                    theme: filterModal.theme
                                    iconText: "🤖"
                                    title: "Service Bot Notices"
                                    description: "Suppress automated ChanServ and NickServ announcement noise in public rooms."
                                    presetKey: "service_bots"
                                    filterName: "service_bots"
                                    tagsSummary: "nick_chanserv,nick_nickserv"
                                    isInstalled: filterModal.isFilterInstalled("service_bots")
                                    onAddRequested: {
                                        relayController.toggle_preset_filter("service_bots")
                                        filterModal.showToast("Added 'Service Bot Notices' to Active Filters")
                                        filterModal.currentTab = 0
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // VIEW 2: CUSTOM FILTER BUILDER
                // ==========================================
                ColumnLayout {
                    id: customFilterView
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "CREATE CUSTOM WEECHAT FILTER"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Text {
                            text: "— Custom name, buffer scope, event tags, and regex pattern (/filter add)"
                            color: theme.textMuted
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: theme.bgSecondary
                        border.color: theme.borderSubtle
                        border.width: 1

                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            Item {
                                width: parent.width
                                implicitHeight: customFormCol.implicitHeight + 36

                                ColumnLayout {
                                    id: customFormCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 20
                                    anchors.rightMargin: 28
                                    spacing: 16

                                    // Filter Name & Buffer Scope Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 16

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 6

                                            Text {
                                                text: "Filter Name *"
                                                color: theme.textSecondary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 40
                                                radius: 8
                                                color: theme.bgInput
                                                border.color: filterNameInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                                clip: true

                                                TextInput {
                                                    id: filterNameInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: theme.textPrimary
                                                    font.pixelSize: 13
                                                    font.family: theme.fontMono
                                                    selectByMouse: true
                                                }

                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "e.g. mute_bot, hide_dice"
                                                    color: theme.textMuted
                                                    font.pixelSize: 12
                                                    font.family: theme.fontMono
                                                    elide: Text.ElideRight
                                                    visible: filterNameInput.text.length === 0 && !filterNameInput.activeFocus
                                                }
                                            }
                                        }

                                        // Buffer Pattern / Scope
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 6

                                            Text {
                                                text: "Buffer / Channel Scope (* for global)"
                                                color: theme.textSecondary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 40
                                                    radius: 8
                                                    color: theme.bgInput
                                                    border.color: bufferPatternInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                                    clip: true

                                                    TextInput {
                                                        id: bufferPatternInput
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 12
                                                        anchors.rightMargin: 12
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        color: theme.textPrimary
                                                        font.pixelSize: 13
                                                        font.family: theme.fontMono
                                                        text: "*"
                                                        selectByMouse: true
                                                    }
                                                }

                                                // Current Buffer Quick Button
                                                Rectangle {
                                                    height: 40
                                                    radius: 8
                                                    implicitWidth: currBufTxt.implicitWidth + 20
                                                    color: curBufHover.hovered ? theme.bgHover : theme.bgElevated
                                                    border.color: theme.borderSubtle

                                                    Text {
                                                        id: currBufTxt
                                                        anchors.centerIn: parent
                                                        text: "Current Buffer"
                                                        color: theme.textSecondary
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    HoverHandler { id: curBufHover }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (relayController.active_buffer_name.length > 0) {
                                                                bufferPatternInput.text = relayController.active_buffer_name
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Event Tags Row
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "Event Tags (comma-separated or click chips to append)"
                                            color: theme.textSecondary
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        // Quick Tag Helper Chips
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            FilterTagChip { tagLabel: "Joins (irc_join)"; tagCode: "irc_join"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Parts (irc_part)"; tagCode: "irc_part"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Quits (irc_quit)"; tagCode: "irc_quit"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Nicks (irc_nick)"; tagCode: "irc_nick"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Modes (irc_mode)"; tagCode: "irc_mode"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Topic (irc_topic)"; tagCode: "irc_topic"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Smart Filter"; tagCode: "irc_smart_filter"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Notice (irc_notice)"; tagCode: "irc_notice"; targetInput: tagsInput; theme: filterModal.theme }
                                            FilterTagChip { tagLabel: "Action (/me)"; tagCode: "irc_action"; targetInput: tagsInput; theme: filterModal.theme }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 40
                                            radius: 8
                                            color: theme.bgInput
                                            border.color: tagsInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                            clip: true

                                            TextInput {
                                                id: tagsInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: theme.textPrimary
                                                font.pixelSize: 13
                                                font.family: theme.fontMono
                                                text: "irc_join,irc_part"
                                                selectByMouse: true
                                            }
                                        }
                                    }

                                    // Regex Pattern Row
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "Regular Expression Pattern (* for any message text)"
                                            color: theme.textSecondary
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 40
                                            radius: 8
                                            color: theme.bgInput
                                            border.color: regexInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                            clip: true

                                            TextInput {
                                                id: regexInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: theme.textPrimary
                                                font.pixelSize: 13
                                                font.family: theme.fontMono
                                                text: "*"
                                                selectByMouse: true
                                            }
                                        }
                                    }

                                    // Command Preview
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 38
                                        radius: 8
                                        color: theme.bgElevated
                                        border.color: theme.borderSubtle

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Text { text: "WeeChat Command:"; color: theme.textMuted; font.pixelSize: 11; font.bold: true }
                                            Text {
                                                text: "/filter add " + (filterNameInput.text.trim().length > 0 ? filterNameInput.text.trim() : "<name>") + " " + bufferPatternInput.text.trim() + " " + tagsInput.text.trim() + " " + regexInput.text.trim()
                                                color: theme.accentCyan
                                                font.family: theme.fontMono
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Submit Button
                                    Rectangle {
                                        Layout.alignment: Qt.AlignRight
                                        height: 40
                                        radius: 8
                                        implicitWidth: addBtnText.implicitWidth + 32
                                        color: (filterNameInput.text.trim().length > 0)
                                            ? (addBtnHover.hovered ? theme.accentHover : theme.accentPrimary)
                                            : theme.bgElevated
                                        border.color: (filterNameInput.text.trim().length > 0) ? theme.accentPrimary : theme.borderSubtle

                                        Text {
                                            id: addBtnText
                                            anchors.centerIn: parent
                                            text: "+ Add Custom Filter"
                                            color: (filterNameInput.text.trim().length > 0) ? theme.bgPrimary : theme.textMuted
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        HoverHandler { id: addBtnHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: (filterNameInput.text.trim().length > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                var name = filterNameInput.text.trim()
                                                if (name.length === 0) return
                                                var buf = bufferPatternInput.text.trim()
                                                var tags = tagsInput.text.trim()
                                                var reg = regexInput.text.trim()
                                                relayController.add_weechat_filter(name, buf, tags, reg)
                                                filterNameInput.text = ""
                                                filterModal.showToast("Created custom filter '" + name + "'")
                                                filterModal.currentTab = 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.borderSubtle
            }

            // Footer Row: Auto-Save Switch and Done Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Auto-save toggle
                ModernSwitch {
                    id: autoSaveSw
                    checked: relayController.auto_save_weechat_filters
                    onToggled: relayController.set_auto_save_weechat_filters(checked)
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Auto-save changes to WeeChat (/save)"
                        color: theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: "Automatically writes modified filters to weechat.conf so they persist across restarts"
                        color: theme.textMuted
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 105
                    height: 40
                    radius: 8
                    color: doneHover.hovered ? theme.accentHover : theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: theme.bgPrimary
                        font.pixelSize: 13
                        font.bold: true
                    }

                    HoverHandler { id: doneHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: filterModal.visible = false
                    }
                }
            }
        }
    }
}
