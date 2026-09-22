
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
```

---

## 🚀 Шаг 1. Создание структуры проекта

Перейдите в корень текущего пользователя:
```bash
cd ~
```

Создайте всю структуру одной bash-командой (Linux / macOS / Git Bash / WSL):

```bash
mkdir -p hello-rust/{.github/workflows,src,tests} && \
cd hello-rust && \

cat > Cargo.toml << 'EOF'
[package]
name = "hello-rust"
version = "0.1.0"
edition = "2021"

[dependencies]

[profile.release]
opt-level = "z"     # оптимизация под размер
lto = true          # link-time optimization
strip = true        # убрать отладочные символы
EOF

cat > src/lib.rs << 'EOF'
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

pub fn sum_range(from: i64, to: i64) -> i64 {
    (from..=to).sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        assert_eq!(greet("Docker"), "Hello, Docker!");
    }

    #[test]
    fn test_sum_range() {
        assert_eq!(sum_range(1, 10), 55);
    }
}
EOF

cat > src/main.rs << 'EOF'
use hello_rust::{greet, sum_range};

fn main() {
    println!("Hello from Rust in Docker! 🦀🐳");
    println!("OS: {}", std::env::consts::OS);
    println!("Arch: {}", std::env::consts::ARCH);
    println!("{}", greet("Docker"));
    println!("Sum 1..10 = {}", sum_range(1, 10));

    let args: Vec<String> = std::env::args().skip(1).collect();
    if !args.is_empty() {
        println!("Аргументы:");
        for (i, arg) in args.iter().enumerate() {
            println!("  {}: {}", i + 1, arg);
        }
    }
}
EOF

cat > tests/integration.rs << 'EOF'
use hello_rust::{greet, sum_range};

#[test]
fn integration_test_greet() {
    assert_eq!(greet("Rust"), "Hello, Rust!");
    assert!(greet("CI").contains("CI"));
}

#[test]
fn integration_test_sum_large() {
    assert_eq!(sum_range(1, 100), 5050);
}
EOF

cat > Dockerfile << 'EOF'
# Этап 1: сборка
FROM rust:1-slim AS builder
WORKDIR /build

# Копируем манифест
COPY Cargo.toml Cargo.lock ./  

# Фиктивный main, чтобы собрать зависимости отдельным слоем
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Собираем зависимости (кэшируется, если Cargo.toml не менялся)
RUN cargo build --release

# Удаляем фиктивный бинарник
RUN rm -f target/release/hello-rust target/release/deps/hello_rust-*

# Копируем настоящий исходник
COPY src ./src
COPY tests ./tests

# Собираем финальный бинарник
RUN cargo build --release

# Этап 2: запуск
FROM debian:stable-slim

# Непривилегированный пользователь
RUN useradd --create-home appuser
WORKDIR /home/appuser

COPY --from=builder /build/target/release/hello-rust ./hello-rust
USER appuser

ENTRYPOINT ["./hello-rust"]
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: Rust CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - name: Cache Cargo
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

      - name: Format check
        run: cargo fmt --check

      - name: Lint with Clippy
        run: cargo clippy --all-targets -- -D warnings

      - name: Run tests
        run: cargo test

      - name: Build release
        run: cargo build --release

      - name: Build Docker image
        run: docker build -t hello-rust .
EOF

cat > .gitignore << 'EOF'
/target
EOF

cat > .dockerignore << 'EOF'
target/
.git/
.github/
*.md
.gitignore
.dockerignore
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

---

## 🐳 Шаг 2. Сборка проекта и тесты в Docker

Rust на хосте не нужен — всё делается внутри контейнера.

**Git Bash / Linux / WSL / macOS:**
```bash
mkdir -p ~/.cargo-docker-cache
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e CARGO_HOME=/tmp/.cargo \
  -v "$(pwd)":/app \
  -v ~/.cargo-docker-cache:/tmp/.cargo \
  -w /app \
  rust:1-slim \
  cargo test
```

**PowerShell:**
```powershell
docker run --rm `
  -e CARGO_HOME=/tmp/.cargo `
  -v "${PWD}:/app" `
  -w /app `
  rust:1-slim `
  cargo test
```

> ⚠️ **В Windows:**
> - Docker Desktop должен быть запущен!
> - Папка проекта должна быть в разрешённых для Docker Desktop дисках. Обычно `C:\` разрешён по умолчанию, но если проект на `D:\` — зайдите в Docker Desktop → Settings → Resources → File Sharing и добавьте диск.
> - Первый запуск будет долгим.

---

## 🔨 Шаг 3. Сборка Docker-образа

Находясь в каталоге проекта:
```bash
cd ~/hello-rust
docker build -t hello-rust .
```

---

## ▶️ Шаг 4. Запуск контейнера

Находясь в каталоге проекта:
```bash
cd ~/hello-rust
docker run --rm hello-rust
```

**Ожидаемый вывод:**
```text
Hello from Rust in Docker! 🦀🐳
OS: linux
Arch: x86_64
Hello, Docker!
Sum 1..10 = 55
```

---

## ⚙️ Команды Cargo (шпаргалка)

| Команда | Что делает |
|---|---|
| `cargo build` | Сборка проекта (debug) |
| `cargo build --release` | Сборка с оптимизацией |
| `cargo run` | Сборка и запуск |
| `cargo test` | Запуск всех тестов |
| `cargo fmt` | Форматирование кода |
| `cargo fmt --check` | Проверка форматирования (для CI) |
| `cargo clippy` | Линтер (поиск ошибок и антипаттернов) |
| `cargo clippy -- -D warnings` | Линтер, где предупреждения = ошибки |

---
