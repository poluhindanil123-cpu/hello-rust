###  CI/CD на Rust с публикацией в GHCR


## Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:
пользователя такую структуру:
hello-rust/
├── .github/workflows/ci.yml
├── src/
│   ├── main.rs
│   └── lib.rs
├── tests/
│   └── integration.rs
├── .gitignore
├── .dockerignore
├── Dockerfile
└── Cargo.toml

Для перехода в корень текущего пользователя:

cd ~

Создать структуру проекта одной bash-командой (Git Bash / Linux / WSL / macOS):

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

cat > Dockerfile << 'EOF'
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
EOF

cat > .github/workflows/ci.yml << 'EOF'
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

