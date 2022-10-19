# Ensure there is a summary for a pull request
fail 'Please provide a summary in the Pull Request description' if github.pr_body.length < 5

# Warn about develop branch
warn("Please target PRs to `develop` branch") if github.branch_for_base != "develop"

# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? "#trivial"

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"

# Warn no CHANGELOG
warn("No CHANGELOG changes made") if git.lines_of_code > 50 && !git.modified_files.include?("CHANGELOG.md") && !declared_trivial

# Warn when there is a big PR
warn("Big PR") if git.lines_of_code > 500

## Let's check if there are any changes in the project folder
has_app_changes = !git.modified_files.grep(/SwiftyStoreKit/).empty?

## Then, we should check if tests are updated
has_test_changes = !git.modified_files.grep(/SwiftyStoreKitTests/).empty?

## Finally, let's combine them and put extra condition
## for changed number of lines of code
if has_app_changes && !has_test_changes && git.lines_of_code > 20
  fail("Tests were not updated", sticky: false)
end
