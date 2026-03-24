//
//  InfoMeetingVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import UIKit

final class InfoMeetingVC: UIViewController {
    var interactor: InfoMeetingBusinessLogic?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let cardView = UIView()

    private let meetingTitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationIconView = UIImageView()
    private let locationLabel = UILabel()

    private let goingTitleLabel = UILabel()
    private let goingStack = UIStackView()

    private let notGoingTitleLabel = UILabel()
    private let notGoingStack = UIStackView()

    private let descriptionLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Текущая встреча"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonTitle = "Назад"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(didTapEdit)
        )
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        interactor?.loadMeeting()
    }

    func apply(viewModel: InfoMeetingViewModel) {
        meetingTitleLabel.text = viewModel.title
        timeLabel.text = viewModel.timeText
        locationLabel.text = viewModel.locationText
        descriptionLabel.text = viewModel.descriptionText

        applyPeople(viewModel.goingPeople, to: goingStack, emptyText: "Пока никто не подтвердил участие")
        applyPeople(viewModel.notGoingPeople, to: notGoingStack, emptyText: "Пока никто не отказался")
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(cardView)

        setupCard()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func setupCard() {
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 24

        [meetingTitleLabel, timeLabel, goingTitleLabel, notGoingTitleLabel, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        locationIconView.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        goingStack.translatesAutoresizingMaskIntoConstraints = false
        notGoingStack.translatesAutoresizingMaskIntoConstraints = false

        meetingTitleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        meetingTitleLabel.textColor = .label
        meetingTitleLabel.numberOfLines = 0

        timeLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        timeLabel.textColor = UIColor(hex: "#6E73F4")

        locationIconView.image = UIImage(systemName: "mappin.circle")
        locationIconView.tintColor = UIColor(hex: "#6E73F4")
        locationIconView.contentMode = .scaleAspectFit

        locationLabel.font = .systemFont(ofSize: 15, weight: .regular)
        locationLabel.textColor = .darkGray
        locationLabel.numberOfLines = 0

        goingTitleLabel.text = "Кто идет"
        goingTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        notGoingTitleLabel.text = "Кто не идет"
        notGoingTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        [goingStack, notGoingStack].forEach {
            $0.axis = .vertical
            $0.spacing = 10
            $0.alignment = .fill
        }

        descriptionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        descriptionLabel.textColor = .label
        descriptionLabel.numberOfLines = 0

        let locationRow = UIStackView(arrangedSubviews: [locationIconView, locationLabel])
        locationRow.translatesAutoresizingMaskIntoConstraints = false
        locationRow.axis = .horizontal
        locationRow.alignment = .top
        locationRow.spacing = 6

        NSLayoutConstraint.activate([
            locationIconView.widthAnchor.constraint(equalToConstant: 20),
            locationIconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let stack = UIStackView(arrangedSubviews: [
            meetingTitleLabel,
            timeLabel,
            locationRow,
            goingTitleLabel,
            goingStack,
            notGoingTitleLabel,
            notGoingStack,
            descriptionLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14

        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }

    private func applyPeople(_ people: [String], to stack: UIStackView, emptyText: String) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let items = people.isEmpty ? [emptyText] : people
        items.forEach { stack.addArrangedSubview(makePersonRow(name: $0, isPlaceholder: people.isEmpty)) }
    }

    private func makePersonRow(name: String, isPlaceholder: Bool) -> UIView {
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = isPlaceholder ? .systemGray3 : .systemGray
        dot.layer.cornerRadius = 7

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14)
        ])

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = isPlaceholder ? .secondaryLabel : .darkGray
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .top
        return stack
    }

    @objc private func didTapEdit() {
        interactor?.didTapEdit()
    }
}
