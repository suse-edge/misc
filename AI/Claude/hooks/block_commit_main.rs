use std::io::{self, Read};
use std::process::Command;

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();

    // Only act on git commit commands
    if !input.contains("git commit") {
        std::process::exit(0);
    }

    // Get the current branch name
    let output = Command::new("git")
        .args(["branch", "--show-current"])
        .output();

    let branch = match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).trim().to_string(),
        Err(_) => std::process::exit(0), // can't determine branch, allow
    };

    if branch == "main" || branch == "master" {
        eprintln!(
            "Blocked: direct commits to '{}' are not allowed. Create a feature branch first.",
            branch
        );
        std::process::exit(2);
    }

    std::process::exit(0);
}
