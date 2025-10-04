import UIKit

final class LandingViewController: UIViewController {
    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.text = "fire off ur random 🔥🎹🤐 keyboard"
        label.font = .systemFont(ofSize: 32, weight: .black)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private let subheadlineLabel: UILabel = {
        let label = UILabel()
        label.text = "get unhinged 👹"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var continueButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Enter the keyboard"
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .systemPink
        configuration.baseForegroundColor = .white

        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(openHomeScreen), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stackView = UIStackView(arrangedSubviews: [headlineLabel, subheadlineLabel, continueButton])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 32

        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -32),
            stackView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor)
        ])
    }

    private func openKeyboardSettings() {
        let message = """
        1. Open Settings.
        2. Go to General → Keyboard → Keyboards → Add New Keyboard…
        3. Find “Mock Keyboard” under Third‑Party Keyboards and tap Add.
        4. Back on the Keyboards list, tap Mock Keyboard and enable Allow Full Access.
        """

        let alert = UIAlertController(title: "Enable Mock Keyboard", message: message, preferredStyle: .alert)

        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    @objc private func openHomeScreen() {
        openKeyboardSettings()
    }
}
