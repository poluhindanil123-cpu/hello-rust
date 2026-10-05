# CI/CD на Rust с публикацией в GHCR

Готовый шаблон проекта на Rust с настроенным CI/CD через GitHub Actions и автоматической публикацией Docker-образа в GitHub Container Registry (GHCR).

---

## 📁 Структура проекта

Создайте в корневом каталоге текущего пользователя следующую структуру:

```
hello-rust/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   ├── main.rs
│   └── lib.rs
├── tests/
│   └── integration.rs
├── .gitignore
├── .dockerignore
├── Dockerfile
└── Cargo.toml
```

---

## 🚀 Быстрое создание (Git Bash / Linux / WSL / macOS)

Перейдите в корень текущего пользователя и выполните одну команду:

```bash
cd ~

mkdir -p hello-rust/{.github/workflows,src,tests} && \
cd hello-rust && \

cat > Cargo.toml << 'EOF'
[package]
name = "hello-rust"
version = "0.1.0"
edition = "2021"

[dependencies]

[profile.release]
opt-level = "z"
lto = true
strip = true
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
```

---

## 🐳 Dockerfile (multi-stage сборка)

```dockerfile
# Этап 1: сборка
FROM rust:1-slim AS builder
WORKDIR /build

# Копируем манифест
COPY Cargo.toml ./

# Фиктивный main, чтобы собрать зависимости отдельным слоем
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -f target/release/hello-rust target/release/deps/hello_rust-*

# Копируем настоящий исходник
COPY src ./src

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
```

---

## ⚙️ GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: Rust CI/CD

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v7

      - name: Set up Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - name: Cache Cargo
        uses: actions/cache@v6
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.toml') }}

      - name: Format check
        run: cargo fmt --check

      - name: Lint with Clippy
        run: cargo clippy --all-targets -- -D warnings

      - name: Run tests
        run: cargo test

      - name: Build release
        run: cargo build --release

      - name: Log in to GHCR
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=,format=short
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v7
        with:
          context: .
          push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## 🚫 Игнорируемые файлы

**`.gitignore`**

```gitignore
/target
```

**`.dockerignore`**

```dockerignore
target/
.git/
.github/
*.md
.gitignore
.dockerignore
```

---

## ✅ Проверка результата

После выполнения скрипта вы должны увидеть список созданных файлов:

```bash
echo "✅ Структура создана:"
find . -type f | sort
```

Ожидаемый вывод:

```
./.dockerignore
./.github/workflows/ci.yml
./.gitignore
./Cargo.toml
./Dockerfile
./src/lib.rs
./src/main.rs
./tests/integration.rs
```

---

## 📝 Что делает CI/CD

| Шаг | Действие |
|-----|----------|
| `Format check` | Проверка форматирования через `rustfmt` |
| `Lint with Clippy` | Статический анализ, предупреждения как ошибки |
| `Run tests` | Юнит- и интеграционные тесты |
| `Build release` | Сборка релизного бинарника |
| `Log in to GHCR` | Авторизация в GitHub Container Registry |
| `Build and push` | Сборка Docker-образа и пуш в GHCR (только для `main`) |

Образ будет доступен по адресу:

```
ghcr.io/<ваш-username>/hello-rust:latest
ghcr.io/<ваш-username>/hello-rust:<short-sha>
```

---

## 🔑 Требования

1. Репозиторий создан на GitHub.
2. Ветка называется `main`.
3. В настройках репозитория разрешена запись пакетов:  
   **Settings → Actions → General → Workflow permissions → Read and write permissions**.
4. Для приватных образов — при необходимости настроить видимость пакета в GHCR.
