#!/usr/bin/env ruby
# Temporary: create a unit-test target wired to the FitnessApp app target and
# add the AsyncState property test to it so the test suite can run.
require 'xcodeproj'

PROJECT_PATH = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp.xcodeproj'
TEST_FILE = '/Users/a12/Documents/fathi/FitnessApp/FitnessAppTests/DesignSystem/AsyncStateTests.swift'

project = Xcodeproj::Project.open(PROJECT_PATH)
app = project.targets.find { |t| t.name == 'FitnessApp' }
abort 'app target missing' unless app

existing = project.targets.find { |t| t.name == 'FitnessAppTests' }
if existing
  puts 'FitnessAppTests target already exists'
else
  test_target = project.new_target(:unit_test_bundle, 'FitnessAppTests', :ios, '16.4', nil, :swift)

  # Wire as host application test bundle
  test_target.add_dependency(app)

  app_bundle_id = app.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.fitnessapp'
  test_target.build_configurations.each do |config|
    bs = config.build_settings
    bs['PRODUCT_BUNDLE_IDENTIFIER'] = "#{app_bundle_id}.FitnessAppTests"
    bs['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FitnessApp.app/FitnessApp'
    bs['BUNDLE_LOADER'] = '$(TEST_HOST)'
    bs['IPHONEOS_DEPLOYMENT_TARGET'] = '16.4'
    bs['SWIFT_VERSION'] = '5.7'
    bs['GENERATE_INFOPLIST_FILE'] = 'YES'
    bs['CODE_SIGN_STYLE'] = 'Automatic'
    bs['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  end

  # Group + file membership (only the AsyncState property test for a clean build)
  test_group = project.main_group['FitnessAppTests'] || project.main_group.new_group('FitnessAppTests', 'FitnessAppTests')
  ds_group = test_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == 'DesignSystem' }
  ds_group ||= test_group.new_group('DesignSystem', 'DesignSystem')
  ref = ds_group.children.find { |c| c.respond_to?(:real_path) && c.real_path.to_s == TEST_FILE }
  ref ||= ds_group.new_reference(TEST_FILE)
  ref.set_path('AsyncStateTests.swift')
  ref.source_tree = '<group>'
  test_target.add_file_references([ref])

  # Add a scheme so xcodebuild test can find it
  project.save
  puts "Created FitnessAppTests target."
end

project.save
puts 'Saved.'
