# 🎓 MathsWithSD — Student Mobile Application

[![Flutter SDK](https://img.shields.io/badge/flutter-v3.0+-blue.svg)](https://flutter.dev/)
[![Dart Language](https://img.shields.io/badge/dart-%3E%3D%203.0-navy.svg)](https://dart.dev/)
[![State Management](https://img.shields.io/badge/state--management-provider-green.svg)](https://pub.dev/packages/provider)
[![Platform Support](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey.svg)](#)

Welcome to the student client application for **MathsWithSD**! This is a modern, responsive mobile application built with **Flutter** and **Dart** designed to empower students with an engaging math learning environment, structured exam assessments, progress diagnostics, and peer leaderboard rankings.

---

## 🚀 Key Features

*   **Interactive Exam Assessment Engine**: Take formal tests designed by teachers. Features a persistent real-time countdown timer, offline answer state caching (via SQLite), and prevention of multi-device session violations.
*   **Self-Assessment Module**: Access a library of self-paced practice exercises, complete with step-by-step mathematical solutions and instant feedback.
*   **LaTeX Math Rendering**: Renders complex formulas, math symbols, algebra, and calculus equations in high resolution using `flutter_math_fork`.
*   **Dynamic Leaderboards & Analytics**: View rank lists and analyze historical performance with high-fidelity visual cards and custom charts showing score distributions and chapter strength.
*   **Teacher Announcements**: Stay updated with a live bulletin feed mapping announcements posted specifically to your class level/cohort.
*   **Reliable Offline Syncing**: Automatically caches questions and saves local exam states to ensure data is preserved even during intermittent network connections.

---

## 🛠️ Technology Stack

*   **UI Framework**: Flutter SDK & Dart
*   **State Management**: Provider (v6.1.5)
*   **Routing & Navigation**: GoRouter (v17.3.0)
*   **Networking**: HTTP & Dio client with custom error-interceptors
*   **Local Caching & Database**: Sqflite (SQLite helper)
*   **Secure Local Storage**: Flutter Secure Storage (for encrypted JWT credentials)
*   **Aesthetics & Media**: custom Google Fonts, cached_network_image, and flutter_avif for image optimization

---

## 📁 Repository Structure

```
mathswithsd/
├── android/                    # Android platform specific configs & Gradle build files
├── ios/                        # iOS platform project configurations
├── assets/
│   └── images/                 # Custom graphic assets, icons, and illustrations
├── lib/
│   ├── models/                 # Dart data classes representing API models (User, Exam, Attempt)
│   ├── providers/              # Provider models managing UI states (Auth, Exam, Leaderboard)
│   ├── screens/                # Widget screens
│   │   ├── student/            # Dashboard, Exam Attempt, Self-Assessment, and Performance analytics
│   │   ├── shared/             # Reusable UI widgets and custom LaTeX display frames
│   │   └── login_screen.dart   # Login screen view
│   ├── services/               # APIs, client interceptors, and local SQLite handlers
│   ├── utils/                  # App constants, dynamic LAN IP settings, theme configs
│   ├── widgets/                # Common UI elements (timers, cards, dialogs)
│   └── main.dart               # App initialization and entry point
├── pubspec.yaml                # Package metadata and dependencies
└── README.md                   # Project documentation
```

---

## ⚙️ Setup & Execution

### Prerequisites

*   **Flutter SDK**: `v3.0.0` or higher
*   **Dart SDK**: `v3.11.5` or higher
*   **Android Studio** / **Xcode** (with configured mobile emulators)
*   **MathsWithSD Backend**: Running local API server

### Running the Application

1.  **Navigate to Directory**:
    ```bash
    cd mathswithsd
    ```

2.  **Configure API Endpoint**:
    To connect a physical mobile device or emulator, locate `lib/utils/constants.dart` and modify `API_BASE_URL` to point to the host computer's active local LAN IP (e.g. `http://192.168.1.50:5000/api/v1`).
    
    *Alternatively, you can run the root setup script `dev-setup.sh` which automatically detects and configures the endpoint for you.*

3.  **Install Packages**:
    ```bash
    flutter pub get
    ```

4.  **Clean Cache (Recommended before first build)**:
    ```bash
    flutter clean
    ```

5.  **Run the App**:
    *   **Debug Mode**:
        ```bash
        flutter run
        ```
    *   **Release Build (Android)**:
        ```bash
        flutter build apk --release
        ```

---

## 👥 Credits

*   **Created by**: [Kalpajit](https://github.com)
*   **Inspired by**: [Debosmit](https://github.com), [Rupam](https://github.com)
*   **Special Thanks**: Soumen Sir, Swagata

---

## 📄 License

This repository is licensed under the [ISC License](LICENSE).
