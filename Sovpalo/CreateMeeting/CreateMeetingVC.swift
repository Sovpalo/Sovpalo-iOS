import UIKit

final class CreateMeetingVC: UIViewController {
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

    var interactor: CreateMeetingBusinessLogic?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Новая встреча"
        setupUI()
        setupPickers()
        setupActions()
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

    private func setupPickers() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "ru_RU")
        datePicker.minimumDate = Date()
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

        let request = CreateMeetingRequest(
            title: placeField.text ?? "",
            date: selectedDate,
            time: selectedTime,
            address: addressField.text ?? "",
            description: descriptionField.text ?? ""
        )

        interactor?.createMeeting(request: request)
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    func showSuccessAndClose() {
        navigationController?.popViewController(animated: true)
    }
}

private extension CreateMeetingVC {
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
