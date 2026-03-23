import UIKit

final class MeetingCell: UITableViewCell {
    static let identifier = "MeetingCell"

    var onGoingTap: (() -> Void)?
    var onNotGoingTap: (() -> Void)?
    var onCancelTap: (() -> Void)?

    private let shadowView = UIView()
    private let cardView = UIView()

    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationIcon = UIImageView()
    private let locationLabel = UILabel()
    private let whoGoesTitleLabel = UILabel()
    private let attendeesStack = UIStackView()

    private let buttonsContainer = UIStackView()
    private let goingButton = UIButton(type: .system)
    private let notGoingButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private var currentStatus: MeetingResponseStatus = .none

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        attendeesStack.arrangedSubviews.forEach {
            attendeesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        onGoingTap = nil
        onNotGoingTap = nil
        onCancelTap = nil
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.08
        shadowView.layer.shadowRadius = 12
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)

        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 22
        cardView.layer.masksToBounds = true

        contentView.addSubview(shadowView)
        shadowView.addSubview(cardView)

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            shadowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            cardView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor)
        ])

        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        timeLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        timeLabel.textColor = UIColor(hex: "#6E73F4")

        locationIcon.image = UIImage(systemName: "mappin.circle")
        locationIcon.tintColor = UIColor(hex: "#6E73F4")
        locationIcon.contentMode = .scaleAspectFit

        locationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        locationLabel.textColor = .darkGray
        locationLabel.numberOfLines = 1

        whoGoesTitleLabel.text = "Кто идет"
        whoGoesTitleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        whoGoesTitleLabel.textColor = .label

        attendeesStack.axis = .vertical
        attendeesStack.spacing = 6
        attendeesStack.alignment = .fill

        buttonsContainer.axis = .horizontal
        buttonsContainer.spacing = 10
        buttonsContainer.distribution = .fillEqually

        [goingButton, notGoingButton, cancelButton].forEach {
            $0.layer.cornerRadius = 22
            $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            $0.heightAnchor.constraint(equalToConstant: 46).isActive = true
        }

        goingButton.addTarget(self, action: #selector(didTapGoing), for: .touchUpInside)
        notGoingButton.addTarget(self, action: #selector(didTapNotGoing), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        buttonsContainer.addArrangedSubview(goingButton)
        buttonsContainer.addArrangedSubview(notGoingButton)

        let mainStack = UIStackView(arrangedSubviews: [
            titleLabel,
            timeLabel,
            makeLocationRow(),
            whoGoesTitleLabel,
            attendeesStack,
            buttonsContainer,
            cancelButton
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 10

        cardView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: 22).cgPath
    }

    private func makeLocationRow() -> UIStackView {
        NSLayoutConstraint.activate([
            locationIcon.widthAnchor.constraint(equalToConstant: 18),
            locationIcon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let stack = UIStackView(arrangedSubviews: [locationIcon, locationLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }

    func configure(with meeting: Meeting) {
        titleLabel.text = "\(meeting.title) \(meeting.dateText)"
        timeLabel.text = meeting.timeText
        if meeting.cityText.isEmpty {
            locationLabel.text = meeting.addressText
        } else {
            locationLabel.text = "\(meeting.cityText), \(meeting.addressText)"
        }

        attendeesStack.arrangedSubviews.forEach {
            attendeesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let visibleAttendees = Array(meeting.attendeesGoing.prefix(2))
        whoGoesTitleLabel.isHidden = visibleAttendees.isEmpty
        attendeesStack.isHidden = visibleAttendees.isEmpty

        for attendee in visibleAttendees {
            attendeesStack.addArrangedSubview(makeAttendeeRow(name: attendee))
        }

        currentStatus = meeting.responseStatus
        applyButtonsState(for: meeting.responseStatus, archived: meeting.isArchived)
    }

    private func makeAttendeeRow(name: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = .systemGray
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12)
        ])

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray

        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }

    private func applyButtonsState(for status: MeetingResponseStatus, archived: Bool) {
        if archived {
            buttonsContainer.isHidden = true
            cancelButton.isHidden = true
            return
        }

        switch status {
        case .none:
            buttonsContainer.isHidden = false
            cancelButton.isHidden = true

            styleFilledButton(goingButton, title: "Иду", selected: true)
            styleFilledButton(notGoingButton, title: "Не иду", selected: false)

        case .going:
            buttonsContainer.isHidden = false
            cancelButton.isHidden = false

            styleFilledButton(goingButton, title: "Иду", selected: true)
            styleFilledButton(notGoingButton, title: "Не иду", selected: false)
            styleOutlineButton(cancelButton, title: "Отменить выбор")

        case .notGoing:
            buttonsContainer.isHidden = false
            cancelButton.isHidden = false

            styleFilledButton(goingButton, title: "Иду", selected: false)
            styleFilledButton(notGoingButton, title: "Не иду", selected: true)
            styleOutlineButton(cancelButton, title: "Отменить выбор")

        case .createdByMe:
            buttonsContainer.isHidden = true
            cancelButton.isHidden = false
            styleOutlineButton(cancelButton, title: "Отменить ✕")
        }
    }
    private func styleFilledButton(_ button: UIButton, title: String, selected: Bool) {
        if selected {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.cornerStyle = .capsule
            config.baseBackgroundColor = UIColor(hex: "#6E73F4")
            config.baseForegroundColor = .white
            button.configuration = config
        } else {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.cornerStyle = .capsule
            config.baseForegroundColor = .label
            config.background.backgroundColor = .white
            config.background.strokeColor = UIColor.systemGray5
            config.background.strokeWidth = 1
            button.configuration = config
        }
    }

    private func styleOutlineButton(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.cornerStyle = .capsule
        config.baseForegroundColor = .label
        config.background.backgroundColor = .white
        config.background.strokeColor = UIColor.systemGray5
        config.background.strokeWidth = 1
        button.configuration = config
    }

    @objc private func didTapGoing() {
        onGoingTap?()
    }

    @objc private func didTapNotGoing() {
        onNotGoingTap?()
    }

    @objc private func didTapCancel() {
        onCancelTap?()
    }
}
