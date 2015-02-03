# Program B
This is the development branch for Program B (Bixsby). This is still a work in progress.

## What is AIML?
AIML (Artificial Intelligence Markup Language) is an XML-compliant language used for building simple AI. It contains everything needed create a chat bot. It matches responses to inputs, stores values, and follows topics.

Here is an example of AIML:
    
    <aiml>
      <category>
        <pattern>WHAT ARE YOU</pattern>
          <template>
            <think><set name="topic">Me</set></think> 
            I am the latest result in artificial intelligence,
            which can reproduce the capabilities of the human brain
            with greater speed and accuracy.
          </template>
      </category>
    </aiml>

    <pattern>   Contains a pattern that can be matched to a user's input.
    <template>  Contains a response for the matched input.

You'll also see in the above example a `<think>` and a `<set>` node. If the user had asked "What are you?", the interpreter matches the pattern, then looks into the `<template>` node for the response. It would then process the `<think>` node, which tells the interpreter to silently process the `<set>` node. In this case, we are setting the current topic value to "Me". Then the interpreter finally outputs the text to the user. AIML contains a hearty list of useful nodes which are all supported by ProgramB. See the full list here: [http://ai.wikia.com/wiki/AIML](http://ai.wikia.com/wiki/AIML)

## Requirments
1. Ruby 2+
2. Nokogiri

#### nokogiri requirements

    $ sudo apt-get install libxslt-dev libxml2-dev
    
    $ gem install nokogiri
    
    -or-

    $ bundle install

## Chatting with ProgramB
ProgramB comes with a CLI tool for testing:
    
    $ ruby bin/programb

## Usage
ProgramB is easy to add to any Ruby application. It's not quite published as a Gem, but you can install ProgramB by either cloning the source, or add it to your Gemfile:

    gem 'programb', :git => 'https://github.com/pacothelovetaco/programb.git'

Here is a simple example of how to implement a chat program with ProgramB

    bixsby = Programb::Kernel.new
    # Load in your AIML director
    bixsby.learn("aiml/alice")

    # Start the loop
    while true
      print "/User #{Time.now.strftime('%H:%M:%S')}> "
      # Get user input
      input = gets.chomp.to_s
      # Get a response from ProgramB
      response = bixsby.respond(input)
      puts "/programB #{Time.now.strftime('%H:%M:%S')}> #{response}"
    end

