#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = '/Users/a12/Documents/fathi/FitnessApp/FitnessApp.xcodeproj'
project = Xcodeproj::Project.open(PROJECT_PATH)
app = project.targets.find { |t| t.name == 'FitnessApp' }
test = project.targets.find { |t| t.name == 'FitnessAppTests' }

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(test)
scheme.set_launch_target(app)
scheme.save_as(PROJECT_PATH, 'FitnessAppTests', true)
puts 'Scheme FitnessAppTests written (shared).'
