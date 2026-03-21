# Coding Conventions

## Общие правила

- Всегда использовать протоколы для сервисов
- Не использовать singletons напрямую
- Использовать Dependency Injection

## Naming

- ViewModel: `FeatureViewModel`
- Repository: `FeatureRepository`
- Service: `FeatureService`

## Пример

Auth:

- AuthViewModel
- AuthRepository
- AuthService

## Ошибки

- Использовать typed errors
- Не использовать `print`, только structured logging

## Async

- Использовать async/await
- Не использовать completion handlers
