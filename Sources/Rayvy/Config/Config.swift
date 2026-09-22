import Foundation

struct LauncherConfig: Equatable, Decodable {
    var hotkey: String = "option+space"

    enum CodingKeys: String, CodingKey {
        case hotkey
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? Self().hotkey
    }
}

struct ClipboardConfig: Equatable, Decodable {
    var enabled: Bool = true
    var maxItems: Int = 100
    var excludedBundleIDs: [String] = []
    var hotkey: String = "cmd+shift+v"

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxItems = "max_items"
        case excludedBundleIDs = "excluded_bundle_ids"
        case hotkey
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        self.maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? defaults.maxItems
        self.excludedBundleIDs = try container.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? defaults.excludedBundleIDs
        self.hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? defaults.hotkey
    }
}

struct HotkeyEntry: Equatable, Decodable {
    var key: String
    var bundleID: String

    enum CodingKeys: String, CodingKey {
        case key
        case bundleID = "bundle_id"
    }
}

struct Config: Equatable, Decodable {
    var launcher: LauncherConfig = LauncherConfig()
    var clipboard: ClipboardConfig = ClipboardConfig()
    var hotkeys: [HotkeyEntry] = []

    enum CodingKeys: String, CodingKey {
        case launcher
        case clipboard
        case hotkeys
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launcher = try container.decodeIfPresent(LauncherConfig.self, forKey: .launcher) ?? LauncherConfig()
        self.clipboard = try container.decodeIfPresent(ClipboardConfig.self, forKey: .clipboard) ?? ClipboardConfig()
        self.hotkeys = try container.decodeIfPresent([HotkeyEntry].self, forKey: .hotkeys) ?? []
    }

    static let `default` = Config()
}

enum ConfigDefaults {
    static let template = """
    [launcher]
    hotkey = "option+space"

    [clipboard]
    enabled = true
    max_items = 100
    excluded_bundle_ids = []
    hotkey = "cmd+shift+v"

    [[hotkeys]]
    key = "option+t"
    bundle_id = "com.mitchellh.ghostty"

    [[hotkeys]]
    key = "option+b"
    bundle_id = "com.apple.Safari"
    """
}
