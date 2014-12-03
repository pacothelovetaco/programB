require File.expand_path '../test_helper.rb', __FILE__
#require 'programb/kernel'

class GraphmasterTest < MiniTest::Test
  
  def setup
    pattern = <<-EOT 
		<pattern>THIS IS A PATTERN</pattern>
		EOT

		template = <<-EOT
		<template>This is a template</template>
		EOT

		that = <<-EOT
		<that>THIS IS A THAT</pattern>
		EOT

		topic = <<-EOT
		<topic>This is a topic<topic>
		EOT

		@pattern = Nokogiri::HTML::DocumentFragment.parse(pattern)
    @template = Nokogiri::HTML::DocumentFragment.parse(template)
		@that = Nokogiri::HTML::DocumentFragment.parse(that)
		@topic = Nokogiri::HTML::DocumentFragment.parse(topic).text
  end
  
  def test_bixsby_can_map_nodes
    graphmaster = Programb::Graphmaster.new(nil)
    graphmaster.map @pattern, @template, @that, @topic

		assert graphmaster.nodemap.has_key?("THIS") != nil, "ERROR: Graphmaster cannot map patterns"
		assert graphmaster.nodemap.has_key?(2) != nil, "ERROR: Graphmaster cannot map templates"
		assert graphmaster.nodemap.has_key?(3) != nil, "ERROR: Graphmaster cannot map that"
		assert graphmaster.nodemap.has_key?(4) != nil, "ERROR: Graphmaster cannot map topic"
  end

  def test_bixsby_can_match_pattern
    graphmaster = Programb::Graphmaster.new(nil)
    graphmaster.map @pattern, @template
		response = graphmaster.match "This is a pattern", @that, @topic
		assert response.text.strip == "This is a template", "ERROR: Graphmaster Match cannot retrieve a response"
  end
end
