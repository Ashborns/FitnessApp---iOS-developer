#!/usr/bin/env ruby
# One-off: add the squat-voice-coaching files (new Swift sources + FitnessModel.mlmodel)
# to the FitnessApp Xcode target, mirroring the existing ExerciseClassifier setup.

require 'xcodeproj'
require 'set'

PROJECT_PATH = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp.xcodeproj'
SOURCE_ROOT  = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp'
TARGET_NAME  = 'FitnessApp'

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
abort "❌ Target '#{TARGET_NAME}' not found" unless target

# Real paths already present in the compile-sources phase.
existing = Set.new
target.source_build_phase.files.each do |bf|
  existing << bf.file_ref.real_path.to_s if bf.file_ref && bf.file_ref.real_path
end

main_group = project.main_group['FitnessApp']
abort "❌ Could not find 'FitnessApp' group" unless main_group

def find_or_create_group(parent, parts)
  return parent if parts.empty?
  name = parts.first
  grp = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
  grp ||= parent.new_group(name, name)
  find_or_create_group(grp, parts[1..])
end

# Files we want to ensure are in the target (relative to SOURCE_ROOT).
wanted = [
  'Features/Camera/SquatPhase.swift',
  'Features/Camera/SquatRepCounter.swift',
  'Features/Camera/FlexFitClassifierManager.swift',
  'Core/Audio/CoachingEvent.swift',
  'Core/Audio/VoiceCoachDecision.swift',
  'Core/Audio/VoiceCoach.swift',
  'Features/Camera/FitnessModel.mlmodel',
]

added = 0
wanted.each do |rel|
  abs = File.join(SOURCE_ROOT, rel)
  unless File.exist?(abs)
    puts "  ⚠️  missing on disk, skipping: #{rel}"
    next
  end
  if existing.include?(abs)
    puts "  ⏭️  already in target: #{rel}"
    next
  end

  parts = rel.split('/')
  filename = parts.pop
  group = find_or_create_group(main_group, parts)

  # Reuse an existing file_ref in the group if present, else create one.
  ref = group.files.find { |f| f.real_path.to_s == abs }
  unless ref
    ref = group.new_reference(abs)
    ref.set_path(filename)
    ref.source_tree = '<group>'
  end

  target.add_file_references([ref])
  puts "  ✅ added: #{rel}"
  added += 1
end

project.save
puts "\n💾 Saved. Added #{added} file(s) to #{TARGET_NAME}."
