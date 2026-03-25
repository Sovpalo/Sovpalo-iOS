//
//  InviteUserVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import UIKit

protocol InviteUserDisplayLogic: AnyObject {
    func displayInviteSuccess(_ response: InviteUserModels.InviteResponse)
    func displayInviteError(_ error: Error)
}

final class InviteUserVC: UIViewController, UITableViewDataSource, UITableViewDelegate, InviteUserDisplayLogic {
    var interactor: InviteUserBusinessLogic?

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Пригласить друзей"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let inputField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Никнейм друга…"
        tf.backgroundColor = .secondarySystemBackground
        tf.layer.cornerRadius = 24
        tf.layer.masksToBounds = true
        tf.textAlignment = .left
        tf.font = .systemFont(ofSize: 17)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 44).isActive = true
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none

        // Left padding view
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 44))
        tf.leftView = leftPadding
        tf.leftViewMode = .always

        return tf
    }()

    private lazy var arrowView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        view.backgroundColor = UIColor(hex: "#7079FB")
        view.layer.cornerRadius = 22
        view.clipsToBounds = true

        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        imageView.image = UIImage(systemName: "arrow.right")
        imageView.tintColor = .white
        imageView.contentMode = .center
        imageView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view.addSubview(imageView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(arrowButtonTapped))
        view.addGestureRecognizer(tapGesture)

        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 52
        return tv
    }()
    
    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Готово", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(hex: "#7079FB")
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        inputField.rightView = arrowView
        inputField.rightViewMode = .always

        inputField.addTarget(self, action: #selector(inputFieldEditingChanged), for: .editingChanged)

        updateArrowViewState()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(InviteStatusCell.self, forCellReuseIdentifier: InviteStatusCell.reuseID)

        let stack = UIStackView(arrangedSubviews: [titleLabel, inputField, tableView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 24
        stack.setCustomSpacing(36, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -24),

            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            doneButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            doneButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            doneButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func arrowButtonTapped() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        Task { [weak self] in
            await self?.interactor?.sendInvite(username: text)
        }
    }

    @objc private func inputFieldEditingChanged() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            inputField.isEnabled = true
            updateArrowViewState()
            return
        }

        // Check if already successfully invited this username
        // Here, instead of .sent, we check for status == "pending"
        let invitations = interactor?.invitations ?? []
        let hasSuccessfulInvite = invitations.contains { $0.username == text && $0.status == "pending" }

        // inputField is never disabled
        inputField.isEnabled = true

        if hasSuccessfulInvite {
            inputField.backgroundColor = UIColor.systemGray5
        } else {
            inputField.backgroundColor = .secondarySystemBackground
        }

        updateArrowViewState()
    }

    private func updateArrowViewState() {
        let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let invitations = interactor?.invitations ?? []
        let hasSuccessfulInvite = invitations.contains { $0.username == text && $0.status == "pending" }

        let isActive = !text.isEmpty && !hasSuccessfulInvite
        arrowView.isUserInteractionEnabled = isActive
        arrowView.backgroundColor = isActive ? UIColor(hex: "#7079FB") : .secondarySystemFill
        // ImageView tintColor remains white always, no change needed here because it's static
    }

    // MARK: - UITableViewDataSource & Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let invitations = interactor?.invitations ?? []
        return invitations.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let invitations = interactor?.invitations ?? []
        let invitation = invitations[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InviteStatusCell.reuseID, for: indexPath) as? InviteStatusCell else {
            // If registration is wrong, return an empty default cell to avoid crash
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        cell.configure(username: invitation.username ?? "", status: invitation.status)
        return cell
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.setViewControllers([FirstGroupAssembly.assembly()], animated: true)
    }

    // MARK: - InviteUserDisplayLogic

    func displayInviteSuccess(_ response: InviteUserModels.InviteResponse) {
        inputField.text = ""
        inputField.backgroundColor = .secondarySystemBackground
        tableView.reloadData()
        updateArrowViewState()
    }

    func displayInviteError(_ error: Error) {
        // If needed, you can check error.localizedDescription or error as string == "error" here, but no changes requested in display
        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        updateArrowViewState()
    }
}

