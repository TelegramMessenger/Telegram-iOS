require 'open-uri'

source_pattern = /(\.m|\.mm|\.h)$/

modified_source_files = git.modified_files.grep(source_pattern)
has_modified_source_files = !modified_source_files.empty?
added_source_files = git.added_files.grep(source_pattern)
has_added_source_files = !added_source_files.empty?

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"

# Warn when there is a big PR
warn("This is a big PR, please consider splitting it up to ease code review.") if git.lines_of_code > 500

# Modifying the changelog will probably get overwritten.
if git.modified_files.include?("CHANGELOG.md") && !github.pr_title.include?("#changelog")
  warn("PR modifies CHANGELOG.md, which is a generated file. Add #changelog to the title to suppress this warning.")
end

def full_license(partial_license, filename)
    license_header = <<-HEREDOC
//
    HEREDOC
    license_header += "//  " + filename + "\n"
    license_header += <<-HEREDOC
//  Texture
//
    HEREDOC
    license_header += partial_license
    return license_header
end

def check_file_header(files_to_check, licenses)
  repo_name = github.pr_json["base"]["repo"]["full_name"]
  pr_number = github.pr_json["number"]
  files = github.api.pull_request_files(repo_name, pr_number)
  files.each do |file|
    if files_to_check.include?(file["filename"])
      filename = File.basename(file["filename"])
    
      data = ""
      contents = github.api.get file["contents_url"]
      open(contents["download_url"]) { |io|
        data += io.read
      }
      
      correct_license = false
      licenses.each do |license|
        license_header = full_license(license, filename)
        if data.include? "Pinterest, Inc."
          correct_license = true
        end
      end
      
      if correct_license == false
        warn ("Please ensure license is correct for #{filename}: \n```\n" + full_license(licenses[0], filename) + "```")
      end
      
    end
  end
end

# Ensure new files have proper header
new_source_license_header = <<-HEREDOC
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
HEREDOC

if has_added_source_files
  check_file_header(added_source_files, [new_source_license_header])
end

# Ensure modified files have proper header
modified_source_license_header = <<-HEREDOC
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
HEREDOC

if has_modified_source_files
  check_file_header(modified_source_files, [modified_source_license_header, new_source_license_header])
end
