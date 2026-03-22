# Архитектура

## Общий подход
Приложение построено по MVVM с разделением на слои:

View → ViewModel → Repository → Service → API Client

## Слои

### 1. View (SwiftUI)
- Только отображение
- Не содержит бизнес-логики
- Использует ViewModel

### 2. ViewModel
- Управляет состоянием UI
- Вызывает use-cases через репозитории
- Не содержит сетевой логики

### 3. Repository
- Абстракция над источниками данных
- Может комбинировать API + local storage
- Используется ViewModel

### 4. Service
- Низкоуровневая логика
- Работа с API / Keychain / QR генерацией

### 5. API Client
- Реализация REST API
- Генерируется/строится на основе OpenAPI

## Dependency Injection

Используется `swift-dependencies`.

Каждый сервис объявляется как dependency:

```swift
struct AuthClient {
    var login: (String, String) async throws -> Token
}
