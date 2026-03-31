//
//  EditMeetingVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import UIKit

final class EditMeetingVC: UIViewController {
    private let placeField = UITextField()
    private let dateField = UITextField()
    private let timeField = UITextField()
    private let addressField = UITextField()
    private let descriptionField = UITextField()
    private let doneButton = UIButton(type: .system)

    private let datePicker = UIDatePicker()
    private let timePicker = UIDatePicker()

    private var selectedDate: Date?
    private var selectedTime: Date?

    var interactor: EditMeetingBusinessLogic?

    override func viewDidLoad() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
        
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Редактировать встречу"
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        setupPickers()
        setupActions()
        interactor?.loadInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    func applyInitialData(_ viewModel: EditMeetingPrefillViewModel) {
        placeField.text = viewModel.title
        dateField.text = viewModel.dateText
        timeField.text = viewModel.timeText
        addressField.text = viewModel.address
        descriptionField.text = viewModel.description

        selectedDate = viewModel.startDate
        selectedTime = viewModel.startDate
        datePicker.date = viewModel.startDate
        timePicker.date = viewModel.startDate
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    func showSuccessAndClose() {
        navigationController?.popViewController(animated: true)
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
            doneButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppLayout.floatingButtonBottomOffset
            ),
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

    private func setupPickers() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "ru_RU")
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .wheels
        timePicker.locale = Locale(identifier: "ru_RU")
        timePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)

        dateField.inputView = datePicker
        timeField.inputView = timePicker

        dateField.tintColor = .clear
        timeField.tintColor = .clear

        dateField.inputAccessoryView = makeToolbar(selector: #selector(donePickingDate))
        timeField.inputAccessoryView = makeToolbar(selector: #selector(donePickingTime))
    }

    private func setupActions() {
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
    }

    private func makeToolbar(selector: Selector) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Готово", style: .done, target: self, action: selector)

        toolbar.items = [flexible, done]
        return toolbar
    }

    @objc private func dateChanged() {
        selectedDate = datePicker.date
        dateField.text = Self.dateFormatter.string(from: datePicker.date)
    }

    @objc private func timeChanged() {
        selectedTime = timePicker.date
        timeField.text = Self.timeFormatter.string(from: timePicker.date)
    }

    @objc private func donePickingDate() {
        if selectedDate == nil {
            selectedDate = datePicker.date
            dateField.text = Self.dateFormatter.string(from: datePicker.date)
        }
        dateField.resignFirstResponder()
    }

    @objc private func donePickingTime() {
        if selectedTime == nil {
            selectedTime = timePicker.date
            timeField.text = Self.timeFormatter.string(from: timePicker.date)
        }
        timeField.resignFirstResponder()
    }

    @objc private func didTapDone() {
        guard let selectedDate else {
            showError(message: "Выберите дату")
            return
        }

        guard let selectedTime else {
            showError(message: "Выберите время")
            return
        }

        let request = EditMeetingRequest(
            title: placeField.text ?? "",
            date: selectedDate,
            time: selectedTime,
            address: addressField.text ?? "",
            description: descriptionField.text ?? ""
        )

        interactor?.updateMeeting(request: request)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {

        guard let userInfo = notification.userInfo,
                let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardHeight = keyboardFrame.height

        // Raise view's elements if the keyboard overlaps the create account button.
        if let desctiptionFrame = descriptionField.superview?.convert(descriptionField.frame, to: nil) {
            let bottomY = desctiptionFrame.maxY
            let screenHeight = UIScreen.main.bounds.height
        
            if bottomY > screenHeight - keyboardHeight {
                let overlap = bottomY - (screenHeight - keyboardHeight)
                self.view.frame.origin.y -= overlap + 16
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
}

private extension EditMeetingVC {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
