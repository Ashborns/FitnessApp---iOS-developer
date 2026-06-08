#!/usr/bin/env ruby
# Auto-add missing Swift files to Xcode project
# Usage: ruby sync_xcode_files.rb

require 'xcodeproj'

PROJECT_PATH = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp.xcodeproj'
SOURCE_ROOT = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp'
TARGET_NAME = 'FitnessApp'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME }

unless target
  puts "❌ Target '#{TARGET_NAME}' not found"
  exit 1
end

# Collect all Swift files already in project
existing_files = Set.new
target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.real_path
    existing_files << build_file.file_ref.real_path.to_s
  end
end

puts "📦 Project: #{TARGET_NAME}"
puts "   Existing Swift files: #{existing_files.size}"
puts ""

# Find all Swift files on disk under FitnessApp/
disk_files = Dir.glob("#{SOURCE_ROOT}/**/*.swift")
puts "   Files on disk: #{disk_files.size}"
puts ""

# Find missing files
missing = disk_files.reject { |f| existing_files.include?(f) }

if missing.empty?
  puts "✅ All Swift files are already in the project."
  exit 0
end

puts "🆕 Adding #{missing.size} missing files:"

# Build group hierarchy (mirroring folder structure)
def find_or_create_group(project, parent_group, parts)
  return parent_group if parts.empty?
  name = parts.first
  group = parent_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
  unless group
    group = parent_group.new_group(name, name)
  end
  find_or_create_group(project, group, parts[1..])
end

# Get the main FitnessApp group
main_group = project.main_group['FitnessApp']
unless main_group
  puts "❌ Could not find 'FitnessApp' group in project."
  exit 1
end

added_count = 0
missing.each do |file_path|
  rel_path = file_path.sub("#{SOURCE_ROOT}/", '')
  parts = rel_path.split('/')
  filename = parts.pop
  group_path = parts

  # Find or create the group hierarchy
  target_group = find_or_create_group(project, main_group, group_path)

  # Add file reference
  file_ref = target_group.new_reference(file_path)
  file_ref.set_path(filename)
  # Set source tree to group so it's relative
  file_ref.source_tree = '<group>'

  # Add to target's compile sources
  target.add_file_references([file_ref])

  puts "  ✅ #{rel_path}"
  added_count += 1
end

# Save project
project.save

puts ""
puts "💾 Saved #{added_count} new files to #{TARGET_NAME}.xcodeproj"
puts "   Open Xcode to verify."
