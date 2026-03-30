import Foundation
import ZvukMusic

enum AppError: Equatable {
    case network
    case timeout
    case unauthorized
    case notFound
    case rateLimited
    case botDetected
    case subscriptionRequired
    case graphQL
    case unknown

    var userMessage: String {
        switch self {
        case .network:
            "Не удалось загрузить данные. Проверьте подключение к интернету."
        case .timeout:
            "Сервер не отвечает. Попробуйте позже."
        case .unauthorized:
            "Ошибка авторизации. Попробуйте войти заново."
        case .notFound:
            "Запрашиваемый контент не найден."
        case .rateLimited:
            "Слишком много запросов. Подождите немного."
        case .botDetected:
            "Доступ временно ограничён. Попробуйте позже."
        case .subscriptionRequired:
            "Для доступа к этому контенту нужна подписка."
        case .graphQL, .unknown:
            "Произошла ошибка. Попробуйте ещё раз."
        }
    }

    static func from(_ error: Error) -> Self? {
        if error is CancellationError { return nil }

        if let zvukError = error as? ZvukError {
            return fromZvuk(zvukError)
        }

        if let urlError = error as? URLError {
            return fromURL(urlError)
        }

        return .unknown
    }

    private static func fromZvuk(_ error: ZvukError) -> Self {
        switch error {
        case .network: .network
        case .timedOut: .timeout
        case .unauthorized: .unauthorized
        case .notFound: .notFound
        case .rateLimited: .rateLimited
        case .botDetected: .botDetected
        case .subscriptionRequired: .subscriptionRequired
        case .graphQL: .graphQL
        case .badRequest, .qualityNotAvailable: .unknown
        }
    }

    private static func fromURL(_ error: URLError) -> Self {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            .network
        case .timedOut:
            .timeout
        default:
            .network
        }
    }
}
