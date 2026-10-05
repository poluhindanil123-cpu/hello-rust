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
