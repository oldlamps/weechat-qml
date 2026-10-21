mod bridge;
mod config;
mod formatting;
mod relay;
mod servers;

use cstr::cstr;
use qmetaobject::*;

use crate::bridge::controller::RelayController;

qrc!(app_resources,
    "qml" {
        "qml/Main.qml" as "Main.qml",
        "qml/Theme.qml" as "Theme.qml",
        "qml/components/BufferSidebar.qml" as "components/BufferSidebar.qml",
        "qml/components/ChatHeader.qml" as "components/ChatHeader.qml",
        "qml/components/MessageListView.qml" as "components/MessageListView.qml",
        "qml/components/MessageDelegate.qml" as "components/MessageDelegate.qml",
        "qml/components/ChatInputBar.qml" as "components/ChatInputBar.qml",
        "qml/components/NickSidebar.qml" as "components/NickSidebar.qml",
        "qml/components/QuickSwitcherModal.qml" as "components/QuickSwitcherModal.qml",
        "qml/components/SettingsDialog.qml" as "components/SettingsDialog.qml",
        "qml/components/ServerManagerDialog.qml" as "components/ServerManagerDialog.qml",
    }
);

fn main() {
    app_resources();

    qml_register_type::<RelayController>(cstr!("WeeChatQml"), 1, 0, cstr!("RelayController"));

    let mut engine = QmlEngine::new();
    engine.load_file("qrc:/qml/Main.qml".into());
    engine.exec();
}
