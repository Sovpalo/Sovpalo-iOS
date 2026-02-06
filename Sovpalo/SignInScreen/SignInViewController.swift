//
//  RegistrationViewController.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import UIKit

final class SignInViewController: UIViewController {
    var interactor: SignInBusinessLogic?
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Вход"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor(hex: "#222222")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Почта"
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 12
        tf.layer.masksToBounds = true
        tf.font = UIFont.systemFont(ofSize: 17)
        tf.setLeftPaddingPoints(16)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return tf
    }()
    
    private let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Пароль"
        tf.autocapitalizationType = .none
        tf.isSecureTextEntry = true
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 12
        tf.layer.masksToBounds = true
        tf.font = UIFont.systemFont(ofSize: 17)
        tf.setLeftPaddingPoints(16)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return tf
    }()
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Забыл пароль?", for: .normal)
        button.setTitleColor(UIColor(hex: "#717171"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        button.contentHorizontalAlignment = .right
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Войти", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(hex: "#404040")
        button.layer.cornerRadius = 22
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#F5F6F7")
        setupLayout()
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        let fieldsStack = UIStackView(arrangedSubviews: [emailTextField, passwordTextField])
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 12
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let contentStack = UIStackView(arrangedSubviews: [titleLabel, fieldsStack, forgotPasswordButton])
        contentStack.axis = .vertical
        contentStack.spacing = 22
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(contentStack)
        view.addSubview(loginButton)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 212),
        
            
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            loginButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
        ])
    }
}

// MARK: - Padding Helper
private extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}
