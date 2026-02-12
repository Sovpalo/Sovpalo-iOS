//
//  StartViewController.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.01.2026.
//

import UIKit

final class StartViewController: UIViewController {
    var interactor: StartBusinessLogic?
    
    // MARK: - UI Elements
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        // Заменить "star.fill" на имя вашей картинки (например, "logo")
        imageView.image = UIImage(named: "logo")
        imageView.tintColor = UIColor.systemIndigo
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Совпало!")
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Встречи с друзьями и близкими")
        label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(String(localized: "Войти"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(hex: "#404040")
        button.layer.cornerRadius = 22
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let bottomLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Нет аккаунта?")
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        let title = String(localized: "Зарегистрируйся")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: UIColor.secondaryLabel,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.contentEdgeInsets = .zero
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        configureLoginButton()
        configureRegisterButton()
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.alignment = .center
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let topStack = UIStackView(arrangedSubviews: [logoImageView, textStack])
        topStack.axis = .vertical
        topStack.spacing = 29
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomRow = UIStackView(arrangedSubviews: [bottomLabel, registerButton])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 4
        bottomRow.alignment = .center
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomStack = UIStackView(arrangedSubviews: [loginButton, bottomRow])
        bottomStack.axis = .vertical
        bottomStack.spacing = 12
        bottomStack.alignment = .center
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(topStack)
        view.addSubview(bottomStack)
        
        titleLabel.numberOfLines = 0
        subtitleLabel.numberOfLines = 0
        
        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 150),
            logoImageView.widthAnchor.constraint(equalToConstant: 150),

            loginButton.heightAnchor.constraint(equalToConstant: 48),

            topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 96),

            bottomStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -113),

            // делаем кнопку на всю ширину по макету
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            bottomStack.topAnchor.constraint(greaterThanOrEqualTo: topStack.bottomAnchor, constant: 40)
        ])
    }
    
    private func configureLoginButton() {
        loginButton.addTarget(self, action: #selector(loginPressed), for: .touchUpInside)
    }
    
    private func configureRegisterButton() {
        registerButton.addTarget(self, action: #selector(registerPressed), for: .touchUpInside)
    }
    
    private func pushLogin() {
        let loginVC = SignInAssembly.assembly()
        navigationController?.pushViewController(loginVC, animated: true)
    }
    
    private func pushRegister() {
        let registerVC = RegisterAssembly.assembly()
        navigationController?.pushViewController(registerVC, animated: true)
    }
    
    @objc private func loginPressed() {
        print("login was pressed")
        pushLogin()
    }
    
    @objc private func registerPressed() {
        print("register was pressed")
        pushRegister()
    }
}
