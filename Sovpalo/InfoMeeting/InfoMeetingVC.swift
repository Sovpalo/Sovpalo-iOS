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
    private let photoImageView = UIImageView()

    private let meetingTitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let locationIconView = UIImageView()
    private let locationLabel = UILabel()

    private let mlContainerView = UIView()
    private let mlTitleLabel = UILabel()
    private let mlPercentLabel = UILabel()
    private let mlProgressView = UIProgressView(progressViewStyle: .default)
    private let mlRecommendationLabel = UILabel()
    private let mlUseRecommendationButton = UIButton(type: .system)
    private var mlBottomToButtonConstraint: NSLayoutConstraint?
    private var mlBottomToLabelConstraint: NSLayoutConstraint?

    private let goingTitleLabel = UILabel()
    private let goingStack = UIStackView()

    private let notGoingTitleLabel = UILabel()
    private let notGoingStack = UIStackView()

    private let descriptionLabel = UILabel()
    
    private let deleteButton = UIButton(type: .system)
    private var photoHeightConstraint: NSLayoutConstraint?
    private var imageLoadTask: Task<Void, Never>?
    private var currentPhotoURL: String?
    private var lastAppliedBottomInset: CGFloat = -1

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
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        interactor?.loadMeeting()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyScrollInsetsForTabBarIfNeeded()
    }

    func apply(viewModel: InfoMeetingViewModel) {
        meetingTitleLabel.text = viewModel.title
        timeLabel.text = viewModel.timeText
        locationLabel.text = viewModel.locationText
        descriptionLabel.text = viewModel.descriptionText
        loadPhotoIfNeeded(from: viewModel.photoURL)

        applyML(viewModel.ml)
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
        scrollView.alwaysBounceVertical = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(cardView)
        contentView.addSubview(deleteButton)

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

            deleteButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 20),
            deleteButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            deleteButton.heightAnchor.constraint(equalToConstant: 54),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func setupCard() {
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 24

        [photoImageView, meetingTitleLabel, timeLabel, goingTitleLabel, notGoingTitleLabel, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        locationIconView.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        goingStack.translatesAutoresizingMaskIntoConstraints = false
        notGoingStack.translatesAutoresizingMaskIntoConstraints = false
        mlContainerView.translatesAutoresizingMaskIntoConstraints = false

        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 18
        photoImageView.isHidden = true

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

        setupMLBlock()
        
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.layer.cornerRadius = 18
        deleteButton.layer.masksToBounds = true

        var config = UIButton.Configuration.filled()
        config.title = "Удалить встречу"
        config.baseBackgroundColor = .systemRed
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        deleteButton.configuration = config

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
            photoImageView,
            meetingTitleLabel,
            timeLabel,
            locationRow,
            mlContainerView,
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

        photoHeightConstraint = photoImageView.heightAnchor.constraint(equalToConstant: 0)
        photoHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }

    private func loadPhotoIfNeeded(from photoURL: String?) {
        imageLoadTask?.cancel()
        currentPhotoURL = photoURL

        guard let photoURL, !photoURL.isEmpty else {
            photoImageView.image = nil
            photoImageView.isHidden = true
            photoHeightConstraint?.constant = 0
            return
        }

        photoImageView.image = nil
        photoImageView.isHidden = false
        photoHeightConstraint?.constant = 220

        imageLoadTask = Task { [weak self] in
            guard let self else { return }
            guard let interactor = self.interactor else { return }
            let image = await interactor.loadMeetingImage(
                from: photoURL,
                targetSize: CGSize(width: UIScreen.main.bounds.width - 80, height: 220)
            )

            if Task.isCancelled { return }

            await MainActor.run {
                guard self.currentPhotoURL == photoURL else { return }
                if let image {
                    self.photoImageView.image = image
                    self.photoImageView.isHidden = false
                    self.photoHeightConstraint?.constant = 220
                } else {
                    self.photoImageView.image = nil
                    self.photoImageView.isHidden = true
                    self.photoHeightConstraint?.constant = 0
                }
            }
        }
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
    
    private func setupActions() {
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        mlUseRecommendationButton.addTarget(self, action: #selector(didTapUseRecommendation), for: .touchUpInside)
    }

    @objc private func didTapEdit() {
        interactor?.didTapEdit()
    }

    @objc private func didTapUseRecommendation() {
        interactor?.didTapUseRecommendation()
    }
    
    @objc private func didTapDelete() {
        let alert = UIAlertController(
            title: "Удалить встречу?",
            message: "Это действие нельзя отменить.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.interactor?.deleteMeeting()
        })

        present(alert, animated: true)
    }

    private func applyScrollInsetsForTabBarIfNeeded() {
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let bottomInset = max(0, tabBarHeight) + 24
        if abs(lastAppliedBottomInset - bottomInset) < 0.5 { return }
        lastAppliedBottomInset = bottomInset
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func setupMLBlock() {
        mlContainerView.backgroundColor = UIColor(hex: "#EEF1FF")
        mlContainerView.layer.cornerRadius = 18
        mlContainerView.layer.borderWidth = 1
        mlContainerView.layer.borderColor = UIColor(hex: "#6E73F4", alpha: 0.2)?.cgColor
        mlContainerView.isHidden = true

        [mlTitleLabel, mlPercentLabel, mlProgressView, mlRecommendationLabel, mlUseRecommendationButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        mlTitleLabel.text = "Прогноз встречи"
        mlTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        mlTitleLabel.textColor = UIColor(hex: "#2B2730")

        mlPercentLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        mlPercentLabel.textColor = UIColor(hex: "#6E73F4")
        mlPercentLabel.text = "—"

        mlProgressView.progressTintColor = UIColor(hex: "#6E73F4")
        mlProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.6)
        mlProgressView.layer.cornerRadius = 4
        mlProgressView.clipsToBounds = true

        mlRecommendationLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        mlRecommendationLabel.textColor = .secondaryLabel
        mlRecommendationLabel.numberOfLines = 0
        mlRecommendationLabel.text = "Считаем рекомендации…"

        var config = UIButton.Configuration.filled()
        config.title = "Открыть с рекомендацией"
        config.baseBackgroundColor = UIColor(hex: "#6E73F4")
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 10, leading: 14, bottom: 10, trailing: 14)
        mlUseRecommendationButton.configuration = config
        mlUseRecommendationButton.isHidden = true

        let headerRow = UIStackView(arrangedSubviews: [mlTitleLabel, UIView(), mlPercentLabel])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.axis = .horizontal
        headerRow.alignment = .center

        mlContainerView.addSubview(headerRow)
        mlContainerView.addSubview(mlProgressView)
        mlContainerView.addSubview(mlRecommendationLabel)
        mlContainerView.addSubview(mlUseRecommendationButton)

        mlBottomToButtonConstraint = mlUseRecommendationButton.bottomAnchor.constraint(equalTo: mlContainerView.bottomAnchor, constant: -14)
        mlBottomToLabelConstraint = mlRecommendationLabel.bottomAnchor.constraint(equalTo: mlContainerView.bottomAnchor, constant: -14)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: mlContainerView.topAnchor, constant: 14),
            headerRow.leadingAnchor.constraint(equalTo: mlContainerView.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: mlContainerView.trailingAnchor, constant: -14),

            mlProgressView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 10),
            mlProgressView.leadingAnchor.constraint(equalTo: mlContainerView.leadingAnchor, constant: 14),
            mlProgressView.trailingAnchor.constraint(equalTo: mlContainerView.trailingAnchor, constant: -14),
            mlProgressView.heightAnchor.constraint(equalToConstant: 8),

            mlRecommendationLabel.topAnchor.constraint(equalTo: mlProgressView.bottomAnchor, constant: 10),
            mlRecommendationLabel.leadingAnchor.constraint(equalTo: mlContainerView.leadingAnchor, constant: 14),
            mlRecommendationLabel.trailingAnchor.constraint(equalTo: mlContainerView.trailingAnchor, constant: -14),

            mlUseRecommendationButton.topAnchor.constraint(equalTo: mlRecommendationLabel.bottomAnchor, constant: 12),
            mlUseRecommendationButton.leadingAnchor.constraint(equalTo: mlContainerView.leadingAnchor, constant: 14),
            mlUseRecommendationButton.trailingAnchor.constraint(lessThanOrEqualTo: mlContainerView.trailingAnchor, constant: -14),
            mlUseRecommendationButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        mlBottomToLabelConstraint?.isActive = true
    }

    private func applyML(_ ml: InfoMeetingMLViewModel?) {
        guard let ml else {
            mlContainerView.isHidden = true
            return
        }

        mlContainerView.isHidden = false

        if let p = ml.probability {
            mlPercentLabel.text = String(format: "%.0f%%", p * 100)
            mlProgressView.setProgress(Float(max(0, min(1, p))), animated: true)
        } else {
            mlPercentLabel.text = "—"
            mlProgressView.setProgress(0, animated: false)
        }

        if let recommendationText = ml.recommendationText {
            if ml.probability != nil {
                mlRecommendationLabel.text = "Лучший вариант: \(recommendationText)"
            } else {
                mlRecommendationLabel.text = recommendationText
            }
        } else {
            mlRecommendationLabel.text = (ml.probability != nil)
                ? "Рекомендации нет: текущий вариант уже близок к лучшему"
                : "Недостаточно данных для прогноза"
        }

        let showButton = ml.canUseRecommendation
        mlUseRecommendationButton.isHidden = !showButton
        mlBottomToButtonConstraint?.isActive = showButton
        mlBottomToLabelConstraint?.isActive = !showButton
    }
}
