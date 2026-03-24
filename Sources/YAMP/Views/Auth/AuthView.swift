import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Звук")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("[unofficial]")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Для входа нужен токен Zvuk.com:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Войдите на zvuk.com в браузере")
                    HStack(spacing: 4) {
                        Text("2. Откройте")
                        Link("zvuk.com/api/tiny/profile",
                             destination: URL(string: "https://zvuk.com/api/tiny/profile")!)
                    }
                    Text("3. Скопируйте значение поля token")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 400, alignment: .leading)

            VStack(spacing: 12) {
                SecureField("Вставьте токен", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
                    .onSubmit {
                        Task { await viewModel.login(appState: appState) }
                    }

                Button {
                    Task { await viewModel.login(appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 80)
                    } else {
                        Text("Войти")
                            .frame(width: 80)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.token.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: 400)
                }
            }

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
}
