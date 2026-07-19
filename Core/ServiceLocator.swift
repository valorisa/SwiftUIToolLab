import Foundation

/// Minimal type-based service locator. Features never look up other
/// features' concrete services directly — only protocols registered here.
protocol ServiceLocating {
    func resolve<T>(_ type: T.Type) -> T?
}

final class ServiceLocator: ServiceLocating {
    static let shared = ServiceLocator()

    private var services: [ObjectIdentifier: Any] = [:]

    private init() {}

    func register<T>(_ type: T.Type, instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    func resolve<T>(_ type: T.Type) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// Test/debug helper. Not used in production flows.
    func reset() {
        services.removeAll()
    }
}
