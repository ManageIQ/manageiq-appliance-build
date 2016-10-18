#!/usr/bin/env ruby

# This script is for development testing. It will generate the kickstarts from the
# ../kickstarts/base.ks.erb and ../kickstarts/partials/*

require 'logger'

require_relative '../scripts/cli'
require_relative '../scripts/git_checkout'
require_relative '../scripts/kickstart_generator'

$log = Logger.new(STDOUT)

options = Build::Cli.parse.options

Build::KickstartGenerator.new(
  File.expand_path("..", __dir__),
  options[:only],
  nil,
  Build::GitCheckout.new(:remote => options[:manageiq_url],  :ref => options[:manageiq_ref]),
  Build::GitCheckout.new(:remote => options[:appliance_url], :ref => options[:appliance_ref]),
  Build::GitCheckout.new(:remote => options[:sui_url],       :ref => options[:sui_ref])).run
