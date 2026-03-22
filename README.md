# dgtu-ios
dstu hack iOS app

# Точка входа (iOS MVP)

MVP приложения цифрового пропуска для сотрудников.

## Основная идея
Приложение генерирует временный QR-код, который используется как цифровой пропуск для входа в здание.

## Основной стек
- Swift
- SwiftUI
- swift-navigation (Point-Free)
- swift-dependencies (Point-Free)
- SPM

## Архитектура
- MVVM
- Repository pattern
- Service layer
- Dependency Injection через swift-dependencies

## Основные фичи
- JWT авторизация
- Хранение пользователя между сессиями
- Генерация QR-кода (валиден 5 минут)
- Блокировка приложения (PIN + Face ID)
- Защита от скриншотов
- Blur при уходе в background

