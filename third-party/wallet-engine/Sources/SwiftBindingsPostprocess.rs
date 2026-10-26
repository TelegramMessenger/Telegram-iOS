#[path = "../wallet-engine/xtask/src/bindings/swift_postprocess.rs"]
mod swift_postprocess;

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};

fn main() -> Result<()> {
    let mut arguments = env::args_os().skip(1).map(PathBuf::from);
    let swift_input = next_path(&mut arguments, "Swift input")?;
    let swift_output = next_path(&mut arguments, "Swift output")?;
    let header_input = next_path(&mut arguments, "header input")?;
    let header_output = next_path(&mut arguments, "header output")?;
    if arguments.next().is_some() {
        bail!("unexpected extra arguments");
    }

    let swift = fs::read_to_string(&swift_input)
        .with_context(|| format!("failed to read {}", swift_input.display()))?;
    write_text(
        &swift_output,
        &swift_postprocess::postprocess_swift(&swift)?,
    )?;

    let header = fs::read_to_string(&header_input)
        .with_context(|| format!("failed to read {}", header_input.display()))?;
    write_text(&header_output, &header)?;
    Ok(())
}

fn next_path(
    arguments: &mut impl Iterator<Item = PathBuf>,
    description: &str,
) -> Result<PathBuf> {
    arguments
        .next()
        .with_context(|| format!("missing {description} path"))
}

fn write_text(path: &Path, source: &str) -> Result<()> {
    let parent = path
        .parent()
        .with_context(|| format!("{} has no parent directory", path.display()))?;
    fs::create_dir_all(parent)
        .with_context(|| format!("failed to create {}", parent.display()))?;
    fs::write(path, normalize_text(source))
        .with_context(|| format!("failed to write {}", path.display()))
}

fn normalize_text(source: &str) -> String {
    let normalized = source
        .lines()
        .map(|line| line.trim_end_matches([' ', '\t']))
        .collect::<Vec<_>>()
        .join("\n");
    format!("{normalized}\n")
}
