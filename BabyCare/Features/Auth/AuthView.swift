import SwiftUI

// MARK: - Login / Register View
struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.pink)
                    Text("BabyCare AI")
                        .font(.largeTitle.bold())
                    Text("记录宝宝每一刻成长")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Toggle
                Picker("", selection: $isLogin) {
                    Text("登录").tag(true)
                    Text("注册").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                // Form
                VStack(spacing: 16) {
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("密码（至少8位）", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !isLogin {
                        SecureField("确认密码", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                // Error
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }

                // Action button
                Button {
                    submit()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isLogin ? "登录" : "注册")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Spacer()

                // Skip (offline mode)
                Button("暂不登录，仅本地使用") {
                    appState.skipAuth()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
    }

    private func submit() {
        let trimEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimPwd   = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimEmail.isEmpty, !trimPwd.isEmpty else {
            errorMessage = "请填写邮箱和密码"
            return
        }
        if !isLogin {
            guard trimPwd == confirmPassword else {
                errorMessage = "两次输入的密码不一致"
                return
            }
            guard trimPwd.count >= 8 else {
                errorMessage = "密码至少需要8位"
                return
            }
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                if isLogin {
                    try await APIClient.shared.login(email: trimEmail, password: trimPwd)
                } else {
                    try await APIClient.shared.register(email: trimEmail, password: trimPwd)
                }
                await MainActor.run { appState.didSignIn() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? SyncError)?.errorDescription ?? error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AuthView().environmentObject(AppState())
}
