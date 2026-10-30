import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: filterModal
    anchors.fill: parent
    color: "#cc090b10"
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

    // Modern Switch Component (responsive, smooth animation, no snap-back)
    component ModernSwitch: Rectangle {
        id: swRoot
        property bool checked: false
        signal toggled(bool newState)

        width: 40
        height: 22
        radius: 11
        color: checked ? theme.accentPrimary : theme.bgInput
        border.color: checked ? theme.accentPrimary : theme.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Rectangle {
            id: swThumb
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: swRoot.checked ? (swRoot.width - width - 3) : 3
            color: swRoot.checked ? theme.bgPrimary : theme.textSecondary

            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        HoverHandler { id: swHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: swRoot.toggled(!swRoot.checked)
        }
    }

    // Inline Tag Chip Helper Component
    component FilterTagChip: Rectangle {
        property string tagLabel: ""
        property string tagCode: ""
        property var targetInput
        property var theme

        height: 26
        radius: 13
        implicitWidth: chipTxt.implicitWidth + 16
        color: chipHover.hovered ? theme.bgHover : theme.bgElevated
        border.color: chipHover.hovered ? theme.accentCyan : theme.borderSubtle
        border.width: 1

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

    // Preset Template Card Component
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
        property bool isActive: false
        signal toggled()
        signal viewRequested()

        Layout.fillWidth: true
        height: 104
        radius: 10
        color: isInstalled && isActive
            ? Qt.alpha(theme.accentPrimary, 0.08)
            : (cardHover.hovered ? theme.bgHover : theme.bgSecondary)
        border.color: isInstalled && isActive
            ? Qt.alpha(theme.accentPrimary, 0.40)
            : (cardHover.hovered ? theme.borderFocus : theme.borderSubtle)
        border.width: 1

        HoverHandler { id: cardHover }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                width: 38
                height: 38
                radius: 9
                color: isInstalled && isActive ? Qt.alpha(theme.accentPrimary, 0.20) : theme.bgElevated

                Text {
                    anchors.centerIn: parent
                    text: iconText
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        text: title
                        color: theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        height: 18
                        radius: 4
                        visible: isInstalled
                        implicitWidth: presetStatusTxt.implicitWidth + 8
                        color: isActive ? Qt.alpha(theme.statusOnline, 0.15) : Qt.alpha(theme.textMuted, 0.15)
                        border.color: isActive ? Qt.alpha(theme.statusOnline, 0.5) : theme.borderSubtle
                        border.width: 1

                        Text {
                            id: presetStatusTxt
                            anchors.centerIn: parent
                            text: isActive ? "Active" : "Paused"
                            color: isActive ? theme.statusOnline : theme.textMuted
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
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

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        text: "Tags: " + tagsSummary
                        color: theme.textMuted
                        font.pixelSize: 10
                        font.family: theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "View rule →"
                        color: theme.accentCyan
                        font.pixelSize: 10
                        font.bold: true
                        visible: isInstalled
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: templateCardRoot.viewRequested()
                        }
                    }
                }
            }

            // Action: Toggle switch if installed, or "+ Add" button if not installed
            Item {
                width: isInstalled ? 40 : (addBtnTxt.implicitWidth + 20)
                height: 30

                ModernSwitch {
                    anchors.centerIn: parent
                    visible: isInstalled
                    checked: isActive
                    onToggled: templateCardRoot.toggled()
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !isInstalled
                    radius: 6
                    color: addPresetHover.hovered ? theme.accentHover : theme.accentPrimary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "+"
                            color: theme.bgPrimary
                            font.bold: true
                            font.pixelSize: 12
                        }

                        Text {
                            id: addBtnTxt
                            text: "Add"
                            color: theme.bgPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    HoverHandler { id: addPresetHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: templateCardRoot.toggled()
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
        width: Math.min(parent.width - 64, 820)
        height: Math.min(parent.height - 64, 700)
        anchors.centerIn: parent
        radius: 14
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
            anchors.topMargin: 16
            anchors.rightMargin: 16
            width: 32
            height: 32
            radius: 8
            z: 20
            color: closeHover.hovered ? theme.bgHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeHover.hovered ? theme.textPrimary : theme.textSecondary
                font.pixelSize: 14
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
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            spacing: 14

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 36
                spacing: 14

                Rectangle {
                    width: 38
                    height: 38
                    radius: 10
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "🛡️"
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        spacing: 10
                        Text {
                            text: "Message Filters"
                            color: theme.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                            font.family: theme.fontSans
                        }

                        Rectangle {
                            height: 20
                            radius: 10
                            implicitWidth: filterBadgeTxt.implicitWidth + 14
                            color: relayController.active_filter_count > 0 ? Qt.alpha(theme.accentCyan, 0.18) : theme.bgSecondary
                            border.color: relayController.active_filter_count > 0 ? theme.accentCyan : theme.borderSubtle
                            border.width: 1

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
                        text: "WeeChat server-side message suppression (/filter). Filtered lines remain preserved in backlog history."
                        color: theme.textSecondary
                        font.pixelSize: 12
                        font.family: theme.fontSans
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Master Filter Engine Toggle Row (Alt+=)
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 8
                color: theme.bgSecondary
                border.color: relayController.filters_global_enabled ? Qt.alpha(theme.accentPrimary, 0.40) : theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: relayController.filters_global_enabled ? Qt.alpha(theme.statusOnline, 0.20) : Qt.alpha(theme.statusWarning, 0.20)

                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            color: relayController.filters_global_enabled ? theme.statusOnline : theme.statusWarning
                            font.pixelSize: 13
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            Text {
                                text: "Global Filter Engine"
                                color: theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Rectangle {
                                height: 16
                                radius: 4
                                implicitWidth: scKbdTxt.implicitWidth + 8
                                color: theme.bgElevated
                                border.color: theme.borderSubtle
                                border.width: 1

                                Text {
                                    id: scKbdTxt
                                    anchors.centerIn: parent
                                    text: "Alt+="
                                    color: theme.textMuted
                                    font.pixelSize: 9
                                    font.family: theme.fontMono
                                }
                            }

                            Rectangle {
                                height: 16
                                radius: 8
                                implicitWidth: statusTxt.implicitWidth + 10
                                color: relayController.filters_global_enabled ? Qt.alpha(theme.statusOnline, 0.15) : Qt.alpha(theme.statusWarning, 0.15)
                                border.color: relayController.filters_global_enabled ? theme.statusOnline : theme.statusWarning
                                border.width: 1

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
                                ? "Filters actively suppressing noise"
                                : "All filters bypassed; raw messages and notices visible"
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
                height: filterModal.toastText.length > 0 ? 32 : 0
                visible: filterModal.toastText.length > 0
                radius: 6
                color: Qt.alpha(theme.accentCyan, 0.12)
                border.color: theme.accentCyan
                border.width: 1
                clip: true

                Behavior on height { NumberAnimation { duration: 140 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text { text: "✓"; color: theme.accentCyan; font.bold: true; font.pixelSize: 12 }
                    Text {
                        text: filterModal.toastText
                        color: theme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "View Active Filters →"
                        color: theme.accentCyan
                        font.pixelSize: 11
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
                height: 38
                radius: 8
                color: theme.bgSecondary
                border.color: theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    // Tab 0: Active Filters
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: filterModal.currentTab === 0 ? theme.bgActive : (tab0Hov.hovered ? theme.bgHover : "transparent")
                        border.color: filterModal.currentTab === 0 ? theme.accentPrimary : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "Active Filters"
                                color: filterModal.currentTab === 0 ? theme.textPrimary : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: filterModal.currentTab === 0
                                font.family: theme.fontSans
                            }

                            Rectangle {
                                height: 16
                                radius: 8
                                implicitWidth: t0Count.implicitWidth + 8
                                color: filterModal.currentTab === 0 ? theme.accentPrimary : theme.bgElevated

                                Text {
                                    id: t0Count
                                    anchors.centerIn: parent
                                    text: activeListView.count
                                    color: filterModal.currentTab === 0 ? theme.bgPrimary : theme.textMuted
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        HoverHandler { id: tab0Hov }
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
                        radius: 6
                        color: filterModal.currentTab === 1 ? theme.bgActive : (tab1Hov.hovered ? theme.bgHover : "transparent")
                        border.color: filterModal.currentTab === 1 ? theme.accentPrimary : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "Preset Templates"
                                color: filterModal.currentTab === 1 ? theme.textPrimary : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: filterModal.currentTab === 1
                                font.family: theme.fontSans
                            }

                            Rectangle {
                                height: 16
                                radius: 8
                                implicitWidth: t1Count.implicitWidth + 8
                                color: filterModal.currentTab === 1 ? theme.accentPrimary : theme.bgElevated

                                Text {
                                    id: t1Count
                                    anchors.centerIn: parent
                                    text: "6"
                                    color: filterModal.currentTab === 1 ? theme.bgPrimary : theme.textMuted
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        HoverHandler { id: tab1Hov }
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
                        radius: 6
                        color: filterModal.currentTab === 2 ? theme.bgActive : (tab2Hov.hovered ? theme.bgHover : "transparent")
                        border.color: filterModal.currentTab === 2 ? theme.accentPrimary : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "+ New Custom Filter"
                                color: filterModal.currentTab === 2 ? theme.textPrimary : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: filterModal.currentTab === 2
                                font.family: theme.fontSans
                            }
                        }

                        HoverHandler { id: tab2Hov }
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
                // VIEW 0: ACTIVE FILTERS
                // ==========================================
                ColumnLayout {
                    id: activeFiltersView
                    spacing: 10

                    // Search and Action Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Search Input
                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: 6
                            color: theme.bgInput
                            border.color: searchFiltersInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "🔍"
                                    font.pixelSize: 11
                                    color: theme.textMuted
                                }

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
                                    anchors.leftMargin: 26
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Filter by name, tag, or buffer..."
                                    color: theme.textMuted
                                    font.pixelSize: 11
                                    visible: searchFiltersInput.text.length === 0 && !searchFiltersInput.activeFocus
                                }

                                Text {
                                    text: "✕"
                                    color: theme.textMuted
                                    font.pixelSize: 11
                                    visible: searchFiltersInput.text.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: searchFiltersInput.text = ""
                                    }
                                }
                            }
                        }

                        // Refresh list button
                        Rectangle {
                            height: 34
                            radius: 6
                            implicitWidth: refreshRow.implicitWidth + 16
                            color: refHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle
                            border.width: 1

                            RowLayout {
                                id: refreshRow
                                anchors.centerIn: parent
                                spacing: 5
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

                        // Add Filter Button (leads to Presets)
                        Rectangle {
                            height: 34
                            radius: 6
                            implicitWidth: addQuickRow.implicitWidth + 18
                            color: addQuickHover.hovered ? theme.accentHover : theme.accentPrimary

                            RowLayout {
                                id: addQuickRow
                                anchors.centerIn: parent
                                spacing: 5
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

                    // Content Area (ListView or Empty State)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Empty State Card (when no filters exist)
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: theme.bgSecondary
                            border.color: theme.borderSubtle
                            border.width: 1
                            visible: activeListView.count === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: theme.bgElevated
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🛡️"
                                        font.pixelSize: 20
                                    }
                                }

                                Text {
                                    text: "No WeeChat filters configured yet"
                                    color: theme.textPrimary
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: "Filters eliminate background noise like join/parts, mute bots, or silence specific users."
                                    color: theme.textSecondary
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                RowLayout {
                                    spacing: 10
                                    Layout.alignment: Qt.AlignHCenter

                                    Rectangle {
                                        height: 34
                                        radius: 6
                                        implicitWidth: bpbtnTxt.implicitWidth + 20
                                        color: bpbtnHover.hovered ? theme.accentHover : theme.accentPrimary

                                        Text {
                                            id: bpbtnTxt
                                            anchors.centerIn: parent
                                            text: "⚡ Browse Presets"
                                            color: theme.bgPrimary
                                            font.pixelSize: 11
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
                                        height: 34
                                        radius: 6
                                        implicitWidth: custBtnTxt.implicitWidth + 20
                                        color: cbtnHover.hovered ? theme.bgHover : theme.bgElevated
                                        border.color: theme.borderSubtle
                                        border.width: 1

                                        Text {
                                            id: custBtnTxt
                                            anchors.centerIn: parent
                                            text: "🛠️ Create Custom Rule"
                                            color: theme.textPrimary
                                            font.pixelSize: 11
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

                        // Native ListView for Active Filters (Smooth scrolling, zero overlapping on updates)
                        ListView {
                            id: activeListView
                            anchors.fill: parent
                            clip: true
                            model: relayController.filter_model
                            spacing: 0
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: activeListVBar
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                id: filterRowDelegate
                                width: activeListView.width
                                property string qText: (searchFiltersInput.text || "").toLowerCase().trim()
                                property string fName: (model.name || "").toString().toLowerCase()
                                property string fTags: (model.tags || "").toString().toLowerCase()
                                property string fBuf: (model.buffer || "").toString().toLowerCase()
                                property bool matchesSearch: qText.length === 0
                                    || fName.indexOf(qText) !== -1
                                    || fTags.indexOf(qText) !== -1
                                    || fBuf.indexOf(qText) !== -1

                                visible: matchesSearch
                                height: matchesSearch ? 76 : 0
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.bottomMargin: 8
                                    anchors.rightMargin: activeListVBar.visible ? 10 : 0
                                    radius: 8
                                    color: model.enabled
                                        ? (filterRowHover.hovered ? theme.bgHover : theme.bgSecondary)
                                        : (filterRowHover.hovered ? theme.bgHover : Qt.alpha(theme.bgSecondary, 0.6))
                                    border.color: model.enabled
                                        ? (filterRowHover.hovered ? theme.borderFocus : Qt.alpha(theme.accentPrimary, 0.35))
                                        : theme.borderSubtle
                                    border.width: 1

                                    HoverHandler { id: filterRowHover }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        // Switch
                                        ModernSwitch {
                                            checked: model.enabled
                                            onToggled: relayController.toggle_weechat_filter(model.name)
                                        }

                                        // Icon
                                        Rectangle {
                                            width: 34
                                            height: 34
                                            radius: 8
                                            color: model.enabled ? Qt.alpha(theme.accentPrimary, 0.18) : theme.bgElevated

                                            Text {
                                                anchors.centerIn: parent
                                                text: filterModal.getFilterIcon(model.name, model.tags)
                                                font.pixelSize: 16
                                            }
                                        }

                                        // Filter Info
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            RowLayout {
                                                spacing: 8
                                                Layout.fillWidth: true

                                                Text {
                                                    text: model.name
                                                    color: model.enabled ? theme.textPrimary : theme.textMuted
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    font.family: theme.fontMono
                                                    elide: Text.ElideRight
                                                }

                                                // Scope Pill
                                                Rectangle {
                                                    height: 18
                                                    radius: 4
                                                    implicitWidth: scTxt.implicitWidth + 8
                                                    color: theme.bgElevated
                                                    border.color: theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: scTxt
                                                        anchors.centerIn: parent
                                                        text: model.buffer === "*" ? "Global (*)" : model.buffer
                                                        color: theme.textSecondary
                                                        font.pixelSize: 10
                                                        font.family: theme.fontMono
                                                    }
                                                }

                                                // Status Tag
                                                Rectangle {
                                                    height: 18
                                                    radius: 4
                                                    implicitWidth: stPillTxt.implicitWidth + 8
                                                    color: model.enabled ? Qt.alpha(theme.statusOnline, 0.15) : Qt.alpha(theme.textMuted, 0.15)
                                                    border.color: model.enabled ? Qt.alpha(theme.statusOnline, 0.5) : theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: stPillTxt
                                                        anchors.centerIn: parent
                                                        text: model.enabled ? "Active" : "Paused"
                                                        color: model.enabled ? theme.statusOnline : theme.textMuted
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }
                                            }

                                            RowLayout {
                                                spacing: 12
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "Tags: " + model.tags
                                                    color: theme.textSecondary
                                                    font.pixelSize: 11
                                                    font.family: theme.fontMono
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: parent.width * 0.55
                                                }

                                                Text {
                                                    text: "• Pattern: " + (model.regex === "*" ? "any (*)" : model.regex)
                                                    color: theme.textMuted
                                                    font.pixelSize: 11
                                                    font.family: theme.fontMono
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        // Delete Button
                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 6
                                            color: delHover.hovered ? Qt.alpha(theme.statusError, 0.20) : "transparent"
                                            border.color: delHover.hovered ? theme.statusError : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🗑"
                                                color: delHover.hovered ? theme.statusError : theme.textMuted
                                                font.pixelSize: 13
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

                // ==========================================
                // VIEW 1: PRESET TEMPLATES
                // ==========================================
                ColumnLayout {
                    id: presetsView
                    spacing: 10

                    Text {
                        text: "POPULAR IRC PRESETS — Ready-to-use suppression rules recommended by WeeChat"
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            width: parent.width
                            implicitHeight: presetsGrid.implicitHeight + 16

                            GridLayout {
                                id: presetsGrid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 10
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 12

                                // Preset 1: Smart Filter
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "🛡️"
                                    title: "Smart Filter (Recommended)"
                                    description: "Hides idle lurkers; only shows join/part/quit events for users who spoke in the last 30 minutes."
                                    presetKey: "smart_filter"
                                    filterName: "irc_smart_filter"
                                    tagsSummary: "irc_smart_filter"
                                    isInstalled: filterModal.isFilterInstalled("irc_smart_filter")
                                    isActive: filterModal.isFilterActive("irc_smart_filter")
                                    onToggled: {
                                        relayController.toggle_preset_filter("smart_filter")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'Smart Filter'")
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 2: Join / Part / Quit Silence
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "🚪"
                                    title: "All Joins, Parts & Quits"
                                    description: "Completely silence all channel entry, departure, and quit notices across all channels to eliminate busy-room flood."
                                    presetKey: "join_part_quit"
                                    filterName: "join_part_quit"
                                    tagsSummary: "irc_join, irc_part, irc_quit"
                                    isInstalled: filterModal.isFilterInstalled("join_part_quit")
                                    isActive: filterModal.isFilterActive("join_part_quit")
                                    onToggled: {
                                        relayController.toggle_preset_filter("join_part_quit")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'All Joins, Parts & Quits'")
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 3: Nick Changes
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "🏷️"
                                    title: "Nickname Changes"
                                    description: "Hide user rename announcements (e.g. Alice is now known as Alice|Away) to keep chat streams clean."
                                    presetKey: "nick_changes"
                                    filterName: "nick_changes"
                                    tagsSummary: "irc_nick"
                                    isInstalled: filterModal.isFilterInstalled("nick_changes")
                                    isActive: filterModal.isFilterActive("nick_changes")
                                    onToggled: {
                                        relayController.toggle_preset_filter("nick_changes")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'Nickname Changes'")
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 4: Channel Modes & Bans
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "🔧"
                                    title: "Channel Modes & Bans"
                                    description: "Hide channel operator, voice, and ban alterations (+o, -v, +b, +q) during mass moderation or raids."
                                    presetKey: "channel_modes"
                                    filterName: "channel_modes"
                                    tagsSummary: "irc_mode"
                                    isInstalled: filterModal.isFilterInstalled("channel_modes")
                                    isActive: filterModal.isFilterActive("channel_modes")
                                    onToggled: {
                                        relayController.toggle_preset_filter("channel_modes")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'Channel Modes & Bans'")
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 5: Topic Changes
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "📢"
                                    title: "Channel Topic Notices"
                                    description: "Hide in-feed topic modification lines since the current channel topic is already displayed in the top header."
                                    presetKey: "topic_changes"
                                    filterName: "topic_changes"
                                    tagsSummary: "irc_topic"
                                    isInstalled: filterModal.isFilterInstalled("topic_changes")
                                    isActive: filterModal.isFilterActive("topic_changes")
                                    onToggled: {
                                        relayController.toggle_preset_filter("topic_changes")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'Channel Topic Notices'")
                                    }
                                    onViewRequested: filterModal.currentTab = 0
                                }

                                // Preset 6: Service Bots
                                FilterTemplateCard {
                                    theme: filterModal.theme
                                    iconText: "🤖"
                                    title: "Service Bot Notices"
                                    description: "Suppress automated ChanServ and NickServ announcement noise in public rooms."
                                    presetKey: "service_bots"
                                    filterName: "service_bots"
                                    tagsSummary: "nick_chanserv, nick_nickserv"
                                    isInstalled: filterModal.isFilterInstalled("service_bots")
                                    isActive: filterModal.isFilterActive("service_bots")
                                    onToggled: {
                                        relayController.toggle_preset_filter("service_bots")
                                        filterModal.showToast((isInstalled && isActive ? "Paused" : "Enabled") + " 'Service Bot Notices'")
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
                    spacing: 10

                    Text {
                        text: "CUSTOM WEECHAT FILTER — Define buffer scope, event tags, and regex pattern (/filter add)"
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
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
                                implicitHeight: customFormCol.implicitHeight + 32

                                ColumnLayout {
                                    id: customFormCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 18
                                    anchors.rightMargin: 24
                                    spacing: 14

                                    // Filter Name & Buffer Scope Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 14

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 5

                                            Text {
                                                text: "Filter Name *"
                                                color: theme.textSecondary
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 36
                                                radius: 6
                                                color: theme.bgInput
                                                border.color: filterNameInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                                border.width: 1
                                                clip: true

                                                TextInput {
                                                    id: filterNameInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: theme.textPrimary
                                                    font.pixelSize: 12
                                                    font.family: theme.fontMono
                                                    selectByMouse: true
                                                }

                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
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
                                            spacing: 5

                                            Text {
                                                text: "Buffer / Channel Scope (* for global)"
                                                color: theme.textSecondary
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 36
                                                    radius: 6
                                                    color: theme.bgInput
                                                    border.color: bufferPatternInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                                    border.width: 1
                                                    clip: true

                                                    TextInput {
                                                        id: bufferPatternInput
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 10
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        color: theme.textPrimary
                                                        font.pixelSize: 12
                                                        font.family: theme.fontMono
                                                        text: "*"
                                                        selectByMouse: true
                                                    }
                                                }

                                                // Current Buffer Button
                                                Rectangle {
                                                    height: 36
                                                    radius: 6
                                                    implicitWidth: currBufTxt.implicitWidth + 16
                                                    color: curBufHover.hovered ? theme.bgHover : theme.bgElevated
                                                    border.color: theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: currBufTxt
                                                        anchors.centerIn: parent
                                                        text: "Current Buffer"
                                                        color: theme.textSecondary
                                                        font.pixelSize: 11
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
                                        spacing: 6

                                        Text {
                                            text: "Event Tags (comma-separated or click chips to append)"
                                            color: theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        // Quick Tag Helper Chips
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6

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
                                            height: 36
                                            radius: 6
                                            color: theme.bgInput
                                            border.color: tagsInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                            border.width: 1
                                            clip: true

                                            TextInput {
                                                id: tagsInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: theme.textPrimary
                                                font.pixelSize: 12
                                                font.family: theme.fontMono
                                                text: "irc_join,irc_part"
                                                selectByMouse: true
                                            }
                                        }
                                    }

                                    // Regex Pattern Row
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Text {
                                            text: "Regular Expression Pattern (* for any message text)"
                                            color: theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 36
                                            radius: 6
                                            color: theme.bgInput
                                            border.color: regexInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                            border.width: 1
                                            clip: true

                                            TextInput {
                                                id: regexInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: theme.textPrimary
                                                font.pixelSize: 12
                                                font.family: theme.fontMono
                                                text: "*"
                                                selectByMouse: true
                                            }
                                        }
                                    }

                                    // Command Preview
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: 6
                                        color: theme.bgElevated
                                        border.color: theme.borderSubtle
                                        border.width: 1

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
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Submit Button
                                    Rectangle {
                                        Layout.alignment: Qt.AlignRight
                                        height: 36
                                        radius: 6
                                        implicitWidth: addBtnText.implicitWidth + 28
                                        color: (filterNameInput.text.trim().length > 0)
                                            ? (addBtnHover.hovered ? theme.accentHover : theme.accentPrimary)
                                            : theme.bgElevated
                                        border.color: (filterNameInput.text.trim().length > 0) ? theme.accentPrimary : theme.borderSubtle
                                        border.width: 1

                                        Text {
                                            id: addBtnText
                                            anchors.centerIn: parent
                                            text: "+ Add Custom Filter"
                                            color: (filterNameInput.text.trim().length > 0) ? theme.bgPrimary : theme.textMuted
                                            font.pixelSize: 12
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
                opacity: 0.7
            }

            // Footer Row: Auto-Save Switch and Done Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

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
                        text: "Writes modified filters to weechat.conf so rules persist across restarts"
                        color: theme.textMuted
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                // Save to WeeChat Button
                Rectangle {
                    height: 36
                    radius: 6
                    implicitWidth: saveBtnContent.implicitWidth + 24
                    color: filterModal.saveNoticeActive
                        ? theme.statusOnline
                        : (saveBtnHover.hovered ? theme.accentHover : theme.accentPrimary)

                    RowLayout {
                        id: saveBtnContent
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: filterModal.saveNoticeActive ? "✓" : "💾"
                            color: theme.bgPrimary
                            font.pixelSize: 12
                        }

                        Text {
                            text: filterModal.saveNoticeActive ? "Saved to WeeChat!" : "Save (/save)"
                            color: theme.bgPrimary
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

                // Done Button
                Rectangle {
                    width: 90
                    height: 36
                    radius: 6
                    color: doneHover.hovered ? theme.accentHover : theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: theme.bgPrimary
                        font.pixelSize: 12
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
