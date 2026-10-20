import QtQuick
import QtQuick.Controls

QtObject {
    id: theme

    // Current selected theme name
    property string activeThemeName: "Catppuccin Mocha"

    // Supported theme list for the settings selector
    readonly property var availableThemes: [
        "Catppuccin Mocha",
        "Tokyo Night",
        "Nord",
        "Dracula",
        "Gruvbox Dark",
        "Solarized Dark",
        "Cyberpunk / Neon",
        "Monokai Pro",
        "GitHub Dark"
    ]

    // Reactive Theme Palette Switcher
    readonly property var currentThemeData: {
        switch (activeThemeName) {
            case "Tokyo Night":
                return {
                    bgPrimary: "#1a1b26",
                    bgSecondary: "#16161e",
                    bgElevated: "#24283b",
                    bgHover: "#2f3549",
                    bgActive: "#3b4261",
                    bgInput: "#13141c",
                    bgHighlightRow: "#322338",
                    borderSubtle: "#292e42",
                    borderFocus: "#7aa2f7",
                    textPrimary: "#c0caf5",
                    textSecondary: "#9aa5ce",
                    textMuted: "#565f89",
                    accentPrimary: "#7aa2f7",
                    accentHover: "#89ddff",
                    accentCyan: "#7dcfff",
                    badgeHighlight: "#f7768e",
                    badgeUnread: "#414868",
                    statusOnline: "#9ece6a",
                    statusWarning: "#e0af68",
                    statusError: "#f7768e"
                }

            case "Nord":
                return {
                    bgPrimary: "#2e3440",
                    bgSecondary: "#242933",
                    bgElevated: "#3b4252",
                    bgHover: "#434c5e",
                    bgActive: "#4c566a",
                    bgInput: "#1e222a",
                    bgHighlightRow: "#3d2b38",
                    borderSubtle: "#3b4252",
                    borderFocus: "#88c0d0",
                    textPrimary: "#eceff4",
                    textSecondary: "#e5e9f0",
                    textMuted: "#d8dee9",
                    accentPrimary: "#88c0d0",
                    accentHover: "#81a1c1",
                    accentCyan: "#8fbcbb",
                    badgeHighlight: "#bf616a",
                    badgeUnread: "#4c566a",
                    statusOnline: "#a3be8c",
                    statusWarning: "#ebcb8b",
                    statusError: "#bf616a"
                }

            case "Dracula":
                return {
                    bgPrimary: "#282a36",
                    bgSecondary: "#21222c",
                    bgElevated: "#343746",
                    bgHover: "#44475a",
                    bgActive: "#6272a4",
                    bgInput: "#191a21",
                    bgHighlightRow: "#442b3b",
                    borderSubtle: "#44475a",
                    borderFocus: "#bd93f9",
                    textPrimary: "#f8f8f2",
                    textSecondary: "#bfbfbf",
                    textMuted: "#6272a4",
                    accentPrimary: "#bd93f9",
                    accentHover: "#ff79c6",
                    accentCyan: "#8be9fd",
                    badgeHighlight: "#ff5555",
                    badgeUnread: "#44475a",
                    statusOnline: "#50fa7b",
                    statusWarning: "#f1fa8c",
                    statusError: "#ff5555"
                }

            case "Gruvbox Dark":
                return {
                    bgPrimary: "#282828",
                    bgSecondary: "#1d2021",
                    bgElevated: "#3c3836",
                    bgHover: "#504945",
                    bgActive: "#665c54",
                    bgInput: "#141617",
                    bgHighlightRow: "#3c2625",
                    borderSubtle: "#3c3836",
                    borderFocus: "#fe8019",
                    textPrimary: "#ebdbb2",
                    textSecondary: "#d5c4a1",
                    textMuted: "#928374",
                    accentPrimary: "#fe8019",
                    accentHover: "#fabd2f",
                    accentCyan: "#8ec07c",
                    badgeHighlight: "#fb4934",
                    badgeUnread: "#504945",
                    statusOnline: "#b8bb26",
                    statusWarning: "#fabd2f",
                    statusError: "#fb4934"
                }

            case "Solarized Dark":
                return {
                    bgPrimary: "#002b36",
                    bgSecondary: "#073642",
                    bgElevated: "#0a4553",
                    bgHover: "#0e5264",
                    bgActive: "#146275",
                    bgInput: "#001e26",
                    bgHighlightRow: "#33222a",
                    borderSubtle: "#0e5264",
                    borderFocus: "#268bd2",
                    textPrimary: "#93a1a1",
                    textSecondary: "#839496",
                    textMuted: "#586e75",
                    accentPrimary: "#268bd2",
                    accentHover: "#2aa198",
                    accentCyan: "#2aa198",
                    badgeHighlight: "#dc322f",
                    badgeUnread: "#073642",
                    statusOnline: "#859900",
                    statusWarning: "#b58900",
                    statusError: "#dc322f"
                }

            case "Cyberpunk / Neon":
                return {
                    bgPrimary: "#080811",
                    bgSecondary: "#0f0f1d",
                    bgElevated: "#18182e",
                    bgHover: "#252545",
                    bgActive: "#343460",
                    bgInput: "#040409",
                    bgHighlightRow: "#3a0e28",
                    borderSubtle: "#252545",
                    borderFocus: "#f72585",
                    textPrimary: "#f1f5f9",
                    textSecondary: "#a5b4fc",
                    textMuted: "#6366f1",
                    accentPrimary: "#f72585",
                    accentHover: "#7209b7",
                    accentCyan: "#4cc9f0",
                    badgeHighlight: "#f72585",
                    badgeUnread: "#252545",
                    statusOnline: "#00f5d4",
                    statusWarning: "#fee440",
                    statusError: "#f72585"
                }

            case "Monokai Pro":
                return {
                    bgPrimary: "#2d2a2e",
                    bgSecondary: "#221f22",
                    bgElevated: "#3a373b",
                    bgHover: "#49454a",
                    bgActive: "#565257",
                    bgInput: "#19181a",
                    bgHighlightRow: "#422834",
                    borderSubtle: "#3a373b",
                    borderFocus: "#ffd866",
                    textPrimary: "#fcfcfa",
                    textSecondary: "#c1c0c0",
                    textMuted: "#727072",
                    accentPrimary: "#ffd866",
                    accentHover: "#a9dc76",
                    accentCyan: "#78dce8",
                    badgeHighlight: "#ff6188",
                    badgeUnread: "#49454a",
                    statusOnline: "#a9dc76",
                    statusWarning: "#ffd866",
                    statusError: "#ff6188"
                }

            case "GitHub Dark":
                return {
                    bgPrimary: "#0d1117",
                    bgSecondary: "#161b22",
                    bgElevated: "#21262d",
                    bgHover: "#30363d",
                    bgActive: "#3b434d",
                    bgInput: "#010409",
                    bgHighlightRow: "#321d26",
                    borderSubtle: "#30363d",
                    borderFocus: "#58a6ff",
                    textPrimary: "#c9d1d9",
                    textSecondary: "#8b949e",
                    textMuted: "#6e7681",
                    accentPrimary: "#238636",
                    accentHover: "#2ea043",
                    accentCyan: "#58a6ff",
                    badgeHighlight: "#f85149",
                    badgeUnread: "#21262d",
                    statusOnline: "#3fb950",
                    statusWarning: "#d29922",
                    statusError: "#f85149"
                }

            case "Catppuccin Mocha":
            default:
                return {
                    bgPrimary: "#1e1e2e",
                    bgSecondary: "#181825",
                    bgElevated: "#313244",
                    bgHover: "#45475a",
                    bgActive: "#585b70",
                    bgInput: "#11111b",
                    bgHighlightRow: "#392437",
                    borderSubtle: "#313244",
                    borderFocus: "#cba6f7",
                    textPrimary: "#cdd6f4",
                    textSecondary: "#a6adc8",
                    textMuted: "#6c7086",
                    accentPrimary: "#cba6f7",
                    accentHover: "#b4befe",
                    accentCyan: "#89dceb",
                    badgeHighlight: "#f38ba8",
                    badgeUnread: "#313244",
                    statusOnline: "#a6e3a1",
                    statusWarning: "#f9e2af",
                    statusError: "#f38ba8"
                }
        }
    }

    // Dynamic Surface Colors bound to currentThemeData
    readonly property color bgPrimary: currentThemeData.bgPrimary
    readonly property color bgSecondary: currentThemeData.bgSecondary
    readonly property color bgElevated: currentThemeData.bgElevated
    readonly property color bgHover: currentThemeData.bgHover
    readonly property color bgActive: currentThemeData.bgActive
    readonly property color bgInput: currentThemeData.bgInput
    readonly property color bgHighlightRow: currentThemeData.bgHighlightRow

    // Dynamic Borders & Dividers
    readonly property color borderSubtle: currentThemeData.borderSubtle
    readonly property color borderFocus: currentThemeData.borderFocus

    // Dynamic Typography
    readonly property color textPrimary: currentThemeData.textPrimary
    readonly property color textSecondary: currentThemeData.textSecondary
    readonly property color textMuted: currentThemeData.textMuted

    // Dynamic Accents & Badges
    readonly property color accentPrimary: currentThemeData.accentPrimary
    readonly property color accentHover: currentThemeData.accentHover
    readonly property color accentCyan: currentThemeData.accentCyan
    readonly property color badgeHighlight: currentThemeData.badgeHighlight
    readonly property color badgeUnread: currentThemeData.badgeUnread
    readonly property color statusOnline: currentThemeData.statusOnline
    readonly property color statusWarning: currentThemeData.statusWarning
    readonly property color statusError: currentThemeData.statusError

    // Font configurations
    property string fontSans: "Inter, Noto Sans, Cantarell, sans-serif"
    property string fontMono: "JetBrains Mono, Fira Code, monospace"
    property int baseFontSize: 13
}
