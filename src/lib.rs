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
