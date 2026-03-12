//
//  CreateMeetingVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import UIKit

final class CreateMeetingVC: UIViewController {
    private let placeField = UITextField()
    private let dateField = UITextField()
    private let timeField = UITextField()
    private let addressField = UITextField()
    private let descriptionField = UITextField()
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Новая встреча"
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupUI() {
        let fields = [
            configuredField(placeField, placeholder: "Место"),
            configuredField(dateField, placeholder: "Дата"),
            configuredField(timeField, placeholder: "Время"),
            configuredField(addressField, placeholder: "Адрес"),
            configuredField(descriptionField, placeholder: "Описание")
        ]

        let stack = UIStackView(arrangedSubviews: fields)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        var config = UIButton.Configuration.filled()
        config.title = "Готово ✓"
        config.baseBackgroundColor = UIColor(hex: "#6E73F4")
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 28, bottom: 14, trailing: 28)
        doneButton.configuration = config
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            doneButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func configuredField(_ field: UITextField, placeholder: String) -> UITextField {
        field.placeholder = placeholder
        field.backgroundColor = .white
        field.layer.cornerRadius = 22
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.systemGray5.cgColor
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return field
    }
}
