import ServiceManagement

protocol LoginItemControlling {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct MainAppLoginItem: LoginItemControlling {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// Status is read from the system every time, never cached, because the user can toggle it in
/// System Settings.
struct LaunchAtLogin {
    private let service: LoginItemControlling

    init(service: LoginItemControlling = MainAppLoginItem()) {
        self.service = service
    }

    var isEnabled: Bool { service.status == .enabled }
    var requiresApproval: Bool { service.status == .requiresApproval }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
