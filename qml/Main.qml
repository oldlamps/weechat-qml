import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import WeeChatQml 1.0
import "components"

ApplicationWindow {
    id: rootWindow
    width: 1280
    height: 820
    minimumWidth: 880
    minimumHeight: 560
    visible: true
    title: {
        var base = "WeeChat QML"
        if (relay.active_buffer_name.length > 0) {
            base = relay.active_buffer_name + " (" + relay.active_buffer_server + ") — WeeChat QML"
        }
        if (relay.total_unread_count > 0) {
            base = "[" + relay.total_unread_count + "] " + base
        }
        return base
    }
    color: appTheme.bgPrimary

    property bool showLeftSidebar: true
    property bool showRightSidebar: true
    property bool forceClose: false

    function toggleWindowVisibility() {
        if (rootWindow.visible && rootWindow.active) {
            rootWindow.hide()
        } else {
            rootWindow.show()
            rootWindow.raise()
            rootWindow.requestActivate()
        }
    }

    function requestQuit() {
        if (relay.confirm_on_quit && !forceClose) {
            rootWindow.show()
            rootWindow.raise()
            rootWindow.requestActivate()
            quitConfirmDialog.openDialog()
        } else {
            forceClose = true
            Qt.quit()
        }
    }

    onClosing: function(close) {
        if (forceClose) {
            return
        }
        if (relay.close_to_tray) {
            close.accepted = false
            rootWindow.hide()
            return
        }
        if (relay.confirm_on_quit) {
            close.accepted = false
            quitConfirmDialog.openDialog()
        }
    }

    Platform.SystemTrayIcon {
        id: systemTray
        visible: true
        icon.name: "weechat"
        icon.source: "qrc:/icons/weechat.png"
        icon.mask: false
        tooltip: {
            var tip = "WeeChat QML"
            if (relay.active_buffer_name.length > 0) {
                tip += " (" + relay.active_buffer_name + ")"
            }
            if (relay.total_unread_count > 0) {
                tip = "[" + relay.total_unread_count + " unread] " + tip
            }
            return tip
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: (rootWindow.visible && rootWindow.active) ? "Hide to System Tray" : "Restore WeeChat QML"
                onTriggered: rootWindow.toggleWindowVisibility()
            }

            Platform.MenuSeparator {}

            Platform.MenuItem {
                text: "Quit WeeChat QML"
                onTriggered: rootWindow.requestQuit()
            }
        }

        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger || reason === Platform.SystemTrayIcon.DoubleClick) {
                rootWindow.toggleWindowVisibility()
            }
        }
    }

    Theme {
        id: appTheme
        Binding on activeThemeName {
            value: relay.theme_name.length > 0 ? relay.theme_name : "Catppuccin Mocha"
        }
        Binding on baseFontSize {
            value: relay.font_size > 0 ? relay.font_size : 13
        }
    }

    RelayController {
        id: relay
        Component.onCompleted: {
            relay.init_controller()
            if (relay.should_show_server_manager_on_startup()) {
                serverManagerDialog.openManager()
            }
        }
        onActive_buffer_changed: {
            chatInputBar.focusInput()
        }
    }

    // Keyboard Shortcuts
    Shortcut {
        sequence: "Ctrl+K"
        enabled: !mediaViewerModal.visible
        onActivated: {
            if (quickSwitcher.visible) {
                quickSwitcher.closeModal()
            } else {
                quickSwitcher.openModal()
            }
        }
    }

    // Next / Previous Channel Shortcuts (Ctrl+Tab & Ctrl+Shift+Tab, Ctrl+PageDown & Ctrl+PageUp, Ctrl+Down & Ctrl+Up)
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_previous_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Page_Down"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Page_Up"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_previous_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Down"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Up"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_previous_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Shift+Down"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Shift+Up"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_previous_buffer()
    }

    // PageUp & PageDown when global focus is elsewhere
    Shortcut {
        sequence: "Page_Up"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: messageListView.scrollPageUp()
    }

    Shortcut {
        sequence: "Page_Down"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: messageListView.scrollPageDown()
    }

    Shortcut {
        sequence: "Home"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: messageListView.scrollToTop()
    }

    Shortcut {
        sequence: "End"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: messageListView.scrollToBottom()
    }

    // Application Quit Shortcut
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: rootWindow.requestQuit()
    }

    // Window Close Shortcut (Ctrl+W)
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: rootWindow.close()
    }

    // Next Unread Hotkeys (Ctrl+U and classic Alt+A)
    Shortcut {
        sequence: "Ctrl+U"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_unread_buffer()
    }

    Shortcut {
        sequence: "Alt+A"
        enabled: !quickSwitcher.visible && !mediaViewerModal.visible
        onActivated: relay.select_next_unread_buffer()
    }

    // Toggle All Filters Shortcut (Classic WeeChat Alt+=)
    Shortcut {
        sequence: "Alt+="
        onActivated: relay.toggle_all_filters()
    }

    // Numbered buffer quick jump shortcuts: Alt+1 through Alt+9
    Shortcut { sequence: "Alt+1"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(1) }
    Shortcut { sequence: "Alt+2"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(2) }
    Shortcut { sequence: "Alt+3"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(3) }
    Shortcut { sequence: "Alt+4"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(4) }
    Shortcut { sequence: "Alt+5"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(5) }
    Shortcut { sequence: "Alt+6"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(6) }
    Shortcut { sequence: "Alt+7"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(7) }
    Shortcut { sequence: "Alt+8"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(8) }
    Shortcut { sequence: "Alt+9"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(9) }
    Shortcut { sequence: "Alt+0"; enabled: !quickSwitcher.visible && !mediaViewerModal.visible; onActivated: relay.select_buffer_by_number(10) }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: !mediaViewerModal.visible
        onActivated: {
            chatHeader.showSearchBar = !chatHeader.showSearchBar
        }
    }

    // Main Three-Pane Desktop Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Pane: Collapsible Buffer Tree & Server List
        BufferSidebar {
            visible: rootWindow.showLeftSidebar
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            relayController: relay
            theme: appTheme
            onOpenServerManagerRequested: serverManagerDialog.openManager()
            onOpenQuickSwitcherRequested: quickSwitcher.openModal()
            onOpenSettingsRequested: settingsDialog.visible = true
        }

        // Center Pane: Header + Message Stream + Rich Input Bar
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ChatHeader {
                id: chatHeader
                Layout.fillWidth: true
                relayController: relay
                theme: appTheme
                showBufferSidebar: rootWindow.showLeftSidebar
                showNickSidebar: rootWindow.showRightSidebar
                onToggleBufferSidebar: rootWindow.showLeftSidebar = !rootWindow.showLeftSidebar
                onToggleNickSidebar: rootWindow.showRightSidebar = !rootWindow.showRightSidebar
                onOpenSettingsRequested: settingsDialog.visible = true
                onFilterManagerRequested: filterManagerModal.visible = true
            }

            MessageListView {
                id: messageListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                relayController: relay
                theme: appTheme
                onMentionNickRequested: function(nick) {
                    chatInputBar.insertMention(nick)
                }
                onExpandMediaRequested: function(mediaType, mediaUrl, streamUrl, audioUrl, title, position, isPlaying, inlineItem) {
                    mediaViewerModal.openMedia(mediaType, mediaUrl, streamUrl, audioUrl, title, position, isPlaying, inlineItem)
                }
            }

            ChatInputBar {
                id: chatInputBar
                Layout.fillWidth: true
                relayController: relay
                theme: appTheme
                onPageUpRequested: messageListView.scrollPageUp()
                onPageDownRequested: messageListView.scrollPageDown()
                onHomeRequested: messageListView.scrollToTop()
                onEndRequested: messageListView.scrollToBottom()
                onQuitRequested: rootWindow.requestQuit()
                onCloseWindowRequested: rootWindow.close()
                onQuickSwitcherRequested: {
                    if (quickSwitcher.visible) {
                        quickSwitcher.closeModal()
                    } else {
                        quickSwitcher.openModal()
                    }
                }
            }
        }

        // Right Pane: Collapsible Nicklist Drawer (shown for channels)
        NickSidebar {
            visible: rootWindow.showRightSidebar && relay.active_buffer_type === "channel"
            Layout.preferredWidth: 215
            Layout.fillHeight: true
            relayController: relay
            theme: appTheme
            onMentionNickRequested: function(nick) {
                chatInputBar.insertMention(nick)
            }
        }
    }

    // Ctrl+K Quick Switcher Modal
    QuickSwitcherModal {
        id: quickSwitcher
        relayController: relay
        theme: appTheme
    }

    // Preferences & Settings Modal
    SettingsDialog {
        id: settingsDialog
        relayController: relay
        theme: appTheme
        onOpenFilterManagerRequested: {
            settingsDialog.visible = false
            filterManagerModal.visible = true
        }
    }

    // Event & Message Filter Manager Modal
    FilterManagerModal {
        id: filterManagerModal
        relayController: relay
        theme: appTheme
    }

    // Persistent Server Manager Modal
    ServerManagerDialog {
        id: serverManagerDialog
        relayController: relay
        theme: appTheme
    }

    // Fullscreen / Expanded Media Viewer Modal (Images & Video)
    MediaViewerModal {
        id: mediaViewerModal
        relayController: relay
        theme: appTheme
    }

    // Quit Confirmation Modal
    QuitConfirmDialog {
        id: quitConfirmDialog
        relayController: relay
        theme: appTheme
        onQuitConfirmed: {
            rootWindow.forceClose = true
            Qt.quit()
        }
    }
}
