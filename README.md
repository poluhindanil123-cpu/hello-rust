###  CI/CD на Rust с публикацией в GHCR


## Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:


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
