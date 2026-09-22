# hello-rust

Учебный проект на Rust для знакомства с **Cargo**, **CI/CD** и **Multi-stage Docker**. Демонстрирует, как собрать минимальный Docker-образ с самодостаточным бинарником.

## 🎯 Цель

Познакомиться с Cargo и Rust CI, получить маленький Docker-образ. Узнать, чем Rust отличается от Java: JAR требует JVM, а Rust-бинарник — самодостаточный, поэтому финальный образ получается в разы меньше.

## 📚 Что вы узнаете

- **Cargo** — `Cargo.toml`, команды `build`, `test`, `fmt`, `clippy`
- **Встроенные тесты** — `#[test]`, unit- и интеграционные тесты
- **Rust компилируется в один бинарник** — в отличие от Java, JRE в образе не нужен
- **Multi-stage Docker** — сборка в `rust`, запуск в `debian-slim`
- **GitHub Actions** — Rust toolchain, кэш Cargo, `docker build`

---

## 📁 Структура проекта

```text
hello-rust/
├── .github/workflows/ci.yml    # Настройка CI (GitHub Actions)
├── src/
│   ├── main.rs                 # Точка входа (исполняемый файл)
│   └── lib.rs                  # Библиотечная логика + unit-тесты
├── tests/
│   └── integration.rs          # Интеграционные тесты
├── .gitignore                  # Что игнорировать в Git
├── .dockerignore               # Что игнорировать в Docker
├── Dockerfile                  # Инструкция для сборки контейнера
└── Cargo.toml                  # Манифест проекта Rust
