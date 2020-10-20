#!/usr/bin/env ruby

# This script is for development testing. It will generate the kickstarts from the
# ../kickstarts/base.ks.erb and ../kickstarts/partials/*

require 'logger'

require_relative '../scripts/cli'
require_relative '../scripts/kickstart_generator'

$log = Logger.new(STDOUT)

options = Build::Cli.parse.options

Build::KickstartGenerator.new(
  File.expand_path("..", __dir__),
  options[:type],
  options[:only],
  options[:product_name],
  nil).run
