require 'nokogiri'
require 'programb/graphmaster'
require 'yaml'
require 'logger'
require 'open3'
require 'shellwords'

module Programb
	class Kernel

    attr_accessor :properties, :predicates, :session, :parser
    
    GLOBAL_SESSION_ID 	 = "global"
    MAX_HISTORY_SIZE 		= 10
    MAX_RECURSION_DEPTH	= 100
    LOGGER               = "[#{Time.now.strftime('%H:%M:%S')}][KERNEL]"
    
    def initialize(properties=nil)
      initialize_logger
      log.info("Loading Programb V#{VERSION} * Copyright Justin Leavitt 2012")
      
      # Load Graphmaster
      
      # Creating a hash for all methods available
      # for parsing AIML nodes. Order matters.
      @parser = {
        "random"      => method(:process_random),
        "bot"         => method(:process_bot),
        "condition"   => method(:process_condition),
        "date"        => method(:process_date),
        "formal"      => method(:process_formal),
        "gender"      => method(:process_gender),
        "get"         => method(:process_get),
        "id"          => method(:process_id),
        "learn"       => method(:process_learn),
        "lowercase"   => method(:process_lowercase),
        "person"      => method(:process_person),
        "person2"     => method(:process_person2),
        "sentence"    => method(:process_sentence),
        "set"         => method(:process_set),
        "size"        => method(:process_size),
        "star"        => method(:process_star),
        "sr"          => method(:process_sr),
        "srai"        => method(:process_srai),
        "input"       => method(:process_input),
        "system"      => method(:process_system),
        "thatstar"    => method(:process_thatstar),
        "bot"         => method(:process_bot),
        "uppercase"   => method(:process_uppercase),
        "version"     => method(:process_version),
        "think"       => method(:process_think)
      }

      # Load bot properties
      @properties = if properties 
                      YAML.load_file(properties)
                    else
                      YAML.load_file(File.join(__dir__, "../../properties.yml"))
                    end

      # Load bot predicates and set defaults
      @predicates = {}
      set_predicate :topic, "Loading Kernel" 
      set_predicate :name, "User"
      set_predicate :that, "Loading Kernel"

      # Load subsitutions
      @subber = YAML.load_file(File.join(__dir__, "../../substitutions.yml"))

      # Create session
      @session = {}
      add_session Kernel::GLOBAL_SESSION_ID
    end

    def log
      @log ||= Logger.new("./logs/chat_#{Time.now}.log", 'daily')
    end

    def initialize_logger
      log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}][KERNEL][#{severity}]: #{msg}\n"
      end
    end

    ##
    # Imports a directory of AIML files, parses the AIML and sends it to
    # the Graphmaster for mapping.
    #
    # @param
    #   directory [String] location to AIML directory
    #
    # @return [void]
    def learn(directory)
      # XSD location for validation
      xsd = Nokogiri::XML::Schema(File.read(File.join(__dir__,'../../AIML.xsd')))

      log.info("Loading AIML")

      # Start timer
      start_time = Time.now

      Dir.open(directory).each do |file|
        next if file == '.' or file == '..' or file == ".DS_Store"

        begin
          # Parse AIML file
          aiml = Nokogiri::XML(File.read("#{directory}/#{file}"))

          # Validate Aiml file
          xsd.validate(aiml).each do |error|
            log.error("#{error.message}")
          end

          # Group nodes for each topic
          if aiml.xpath('//topic').any?
            extract_topic(aiml)
          end

          extract_category(aiml)
          
          log.info("File loaded: #{file}")
        rescue Exception => e
          log.error("Could not load #{file}. #{e.message}")
          next
        end
      end

      # End Timer
      end_time = Time.now
      log.info("AIML loaded in #{end_time-start_time}s")
    end

    def extract_topic(aiml)
      value = aiml.xpath('//topic')
      topic = value[0].attr('name')
      
      # Grab all category nodes
      topic_categories = aiml.xpath("//topic/category")

      topic_categories.map do |xml|
        send_to_graphmaster(xml, topic)
      end
    end

    def extract_category(aiml)
      category = aiml.xpath("//category") - aiml.xpath("//topic/category")

      # Loop through all category nodes and pull out patterns/templates
      category.map do |xml|
        send_to_graphmaster(xml)
      end
    end


    def send_to_graphmaster(xml, topic=nil)
      # Find pattern
      pattern = xml.xpath('pattern')

      # Determine if <that> exists, if not then set it to nil
      xml.xpath('that').any? ? that = xml.xpath('that') : that = nil

      # Find template
      template = xml.xpath('template')

      # Send all AIML nodes to the Graphmaster for nodemapping.
      brain.map(pattern, template, that, topic)
    end

    ##
    # Begins the matching process from a user's input. The user's input is
    # sent to the Graphmaster, where response will be returned based on
    # the match.
    # 
    # @param
    #   input [String] user's input to be matched. Can be multiple sentences.
    #   session_id [Hash] current chat session
    #
    # @return [String] template response that matches a pattern 
    def respond(input, session_id=Kernel::GLOBAL_SESSION_ID)

      # Create new session if doesn't already exist
      add_session session_id
      
      log.info("User: #{input}")

      # Store the final response
      final_response = ""

      # Split input into sentences and process each seperately
      sentences = input.split(/\.|\?|\!/)
      sentences.each do |sentence|
        # Push sentence into the input history
        input_history = @session[session_id][:input_history]
        input_history << sentence
        while input_history.count > Kernel::MAX_HISTORY_SIZE
          input_history.shift
        end

        # If max recursion is hit, then report and kick out default response.
        input_stack = @session[session_id][:input_stack]
        if input_stack.count > Kernel::MAX_RECURSION_DEPTH
          log.debug("max recursion depth exceeded.") if $VERBOSE	
          next
          return respond("random pickup line", session_id)
        end
        input_stack << sentence
        subbed_sentence = subber(sentence, :contractions)

        # Set 'that'
        output_history = @session[session_id][:output_history]
        !output_history[-1].nil? ? that = output_history[-1] : that = "" 
        subbed_that = subber(that, :contractions)

        # Set 'topic'
        topic = @predicates[:topic]
        subbed_topic = subber(topic, :contractions)

        response = ""
        template = brain.match(subbed_sentence, subbed_that, subbed_topic)

        # If no match, or template.nil?, kick out random response.
        if template.nil?
          log.error("No match found for input") 
          return respond("random pickup line", session_id)
        else
          response = process_response(template, session_id)
        end

        # pop input stack
        input_stack = @session[session_id][:input_stack]
        input_stack.pop()

        # Add response to output history
        output_history = @session[session_id][:output_history]
        output_history << response
        while output_history.count > Kernel::MAX_HISTORY_SIZE
          output_history.shift
        end

        final_response += "#{response} "
      end

      log.info("#{@properties[:name]}: #{final_response.strip}")

      # Return final response
      final_response.strip.squeeze(" ")
    end

		private

    def brain
      @brain ||= Graphmaster.new(log)
    end

    ##
    # Reformats sentences by expanding contractions or switching pronouns
    # <person>
    # <person2>
    #
    # Subsituions are found in subsitutions.yml
    #
    # @example
    #   If a user types "I'm gonna go there.", the method
    #   reformats the sentence to "I am going to go there."
    #
    # @param
    #   input [String] the sentence to format
    #   sub_type [String] flag that designates what type of subsitution
    #
    # @return [String]
    def subber(input, sub_type)
      input = input.downcase
      input = input.gsub(/\.|\?|\!/, "")
      subsitute = input.split(" ")

      subsitute.each do |key|
        if @subber[sub_type].has_key?(key)
          index = subsitute.index(key)
          subsitute[index] = @subber[sub_type][key]
        end
      end

      subsitute.join(" ")
    end


    ##
    # Sets predicates.
    #
    # @param
    #   name [Symbol] name of the predicate
    #   value [String] value to set.
    #
    # @return [Void]
    def set_predicate(name, value)
      name = name.to_sym
      log.debug("Setting '#{name}' to '#{value}'.") if $VERBOSE
      @predicates[name] = value
    end


    ##
    # Gets value from predicates.
    #
    # @param
    #   name [Symbol] name of the predicate
    #
    # @return [String]
    def get_predicate(name)
      name = name.to_sym

      begin 
        @predicates[name]
      rescue
        ""
      end
    end


    ##
    # Set value for session
    #
    # @param
    #   session_id [Integer]
    #   name [Symbol]
    #   value [String]
    #
    # @return [Void]
    def set_session(session_id, name, value)
      @session[session_id][name] = value
    end


    ##
    # Get value for session
    #
    # @param
    #   session_id [Integer]
    #   name [Symbol]
    #
    # @return [Void]
    def get_session(session_id, name)
      @session[session_id][name]
    end

    
    ##
    # Create a session. A session stores input and output history.
    #
    # @param
    #   session_id [Integer]
    #
    # @return [Hash]
    def add_session(session_id)
      return if @session.has_key?(session_id)

      # Create session if one isn't already started
      @session[session_id] = {
        :input_history => [],
        :output_history => [],
        :input_stack => []
      }
    end


    ##
    # Processes the Aiml in the template (response)
    # 
    # The template is turned into HTML so that Nokogiri can parse
    # and locate the AIML tags if they exist. 
    #
    # @param
    #   template [String] the response to a matching pattern
    #   session_id [String] user's current session
    #
    # @return
    #   [String] the processed AIML tag
    #
    # @TODO
    # + Gossip
    # + Refactor Learn method 
    def process_response(template, session_id)
      element = Nokogiri::HTML::DocumentFragment.parse(template.to_s)
      log.debug("Processing response: #{template.to_s.strip}") if $VERBOSE


      # Since Nokogiri grabs the first node it finds,
      # each node is put in an array based on it place in
      # the template HTML
      #
      # TODO add an example.
      parser_stack = []

      element.traverse do |node| 
        if !node.text? && node.name != "li" 
          parser_stack << node
        end
      end
     
      # Grab the first element since that is
      # the most inner tag within <template>.
      # We need to process that tag first.
      aiml_tag = parser_stack.first
      parser_stack.each_with_index do |node, i|
        if node.name == 'random'
          aiml_tag = parser_stack[i]
          break
        end
        aiml_tag = parser_stack.first
      end 
      
      if @parser.has_key?(aiml_tag.name)
        log.debug("Processing <#{aiml_tag.name}>") if $VERBOSE
        
        output = @parser[aiml_tag.name].call(aiml_tag, session_id)
        
        template_string = element.to_s
        parsed_response = template_string.gsub(aiml_tag.to_s, output.to_s)
        process_response(parsed_response, session_id)
      else
        element.text
      end
    end


    #
    ## AIML element processors
    #

    ##
    # Process <system> AIML element
    #
    # <system> executes a terminal command on the server.
    def process_system(element, session_id)
      command = element.text
      log.debug("Processing command: '#{command}'") if $VERBOSE
      #exec(command)
      captured_stdout = ''
      captured_stderr = ''
      exit_status = Open3.popen3(*command.shellsplit) {|stdin, stdout, stderr, wait_thr|
        pid = wait_thr.pid # pid of the started process.
        stdin.close
        captured_stdout = stdout.read
        captured_stderr = stderr.read
        wait_thr.value # Process::Status object returned.
      }
      if exit_status.success?
        captured_stdout.strip
      else
        captured_stderr.strip
      end
    end

    ##
    # Process <bot> AIML element
    #
    # <bot> are used to fetch bot specific predicates.
    # The 'name' attribute is processed returns the saved value.
    # An empty string is returned if the property
    # doesn't exist
    def process_bot(element, session_id)
      name = element.attr('name')
      @properties.has_key?(name) ? output = @properties[name] : output = ""
    end


    ##
    # Process <date> AIML element
    #
    # <date> returns the current date and time
    # when called.
    def process_date(element, session_id)
      time = Time.new
      time.strftime("%A %B %d, %Y %H:%M%p")
    end


    ##
    # Process <uppercase> AIML element
    #
    # <uppercase> processes and text between the
    # elements and returns them in uppercase.
    def process_uppercase(element, session_id)
      string = element.text
      string.upcase
    end

    
    ##
    # Process <lowercase> AIML element
    #
    # <lowercase> processes and text between the
    # elements and returns them in uppercase.
    def process_lowercase(element, session_id)
      string = element.text
      string.downcase
    end

    
    ##
    # Process <lowercase> AIML element
    #
    # <lowercase> processes and text between the
    # elements and returns them in uppercase.
    def process_sentence(element, session_id)
      string = element.text
      string.capitalize
    end

    
    ##
    # Process <set> AIML element
    #
    # <set> require a 'name' attribute. The
    # attribute is processed and pushed into
    # the predicate hash.
    def process_set(element, session_id)
      name  = element.attr('name')
      value = element.text
      
      set_predicate name, value
      value
    end

    ##
    # Process <get>
    def process_get(element, session_id)
      name = element.attr('name')
      
      begin
        get_predicate name
      rescue
        log.error("Predicate #{name} does not exist!")
        name
      end
    end

    
    ##
    # Process <size>
    def process_size(element, session_id)
      brain.category_count.to_s
    end

    
    ##
    # Process <srai>
    def process_srai(element, session_id)
      respond(element.text, session_id)
    end

    ##
    # Process <formal>
    def process_formal(element, session_id)
      string = element.text
      string.split(/(\W)/).map(&:capitalize).join
    end

    ##
    # Process <condition>
    def process_condition(element, session_id)
      if element.attr('name') && element.attr('value')
        name = element.attr('name')
        value = element.attr('value')
        
        condition = element.inner_html
        
        bot_predicate = get_predicate(name)

        if bot_predicate == value
          return condition
        end

      elsif element.attr('name')
        name = element.attr('name')

        # Get list items
        list_items = element.css('li')
    
        list_items.each do |li|
          if li.attr('value')
            value = li.attr('value')
            list_item = li.inner_html
            bot_predicate = get_predicate name

            if bot_predicate == value
              return list_item
            end
          else
            return li.inner_html
          end
        end
      
      else
        return ""
      end
    end

    ##
    # Process <gender>
    #
    def process_gender(element, session_id)
      gender = element.text
      subber gender, :gender
    end
    
    ##
    # Process <id>
    #
    # returns session id
    def process_id(element, session_id)
      @session.keys[0]
    end
    
    ##
    # Process <input>
    #
    # Returns a previous response from the
    # input stack.
    #
    # Optional Attributes:
    # index: element in the :input_history
    #
    # Sometimes, an input is processed with <srai> and so
    # the input will be saved in caps. The issue is resolved
    # by normalizing the output with 'capitalize'.
    def process_input(element, session_id)

      previous_input = @session[session_id][:input_history]
      
      begin
        if element.attr('index')
          index = element.attr('index').to_i
          output = previous_input[-index]
        else
          output = previous_input[-1]
        end
        
        output.downcase
      
      rescue
        ""
      end
    end

    ##
    # Process <learn>
    #
    def process_learn(element, session_id)
      learn = element.xpath('learn')
      #restructure learn method for this
    end

    ##
    # Process <person>
    #
    def process_person(element, session_id)
      if element.inner_html.empty?
        # Special case for <person/>
        process_star(element, session_id)
      else
        person = element.text
        subber person, :person
      end
    end

    ##
    # Process <person2>
    #
    def process_person2 element, session_id
      if element.inner_html.empty?
        # Special case for <person2/>
        process_star element, session_id
      else
        person2 = element.text
        subber person2, :person2
      end
    end

    ##
    # Process <random>
    # 
    def process_random element, session_id

        random_items = []
        list_items = element.css('li')

        list_items.each do |li|
          random_items << li.inner_html
        end

        random_items.sample
    end

    ##
    # Process <version>
    #
    def process_version element, session_id
      Programb::VERSION
    end

    ##
    # Process <star>
    #
    def process_star element, session_id
      # Get input
      input_stack = @session[session_id][:input_stack]
      input = input_stack[-1]
      input = subber input, :contractions

      # Set 'that'
      output_history = @session[session_id][:output_history]
      !output_history[-1].nil? ? that = output_history[-1] : that = "" 
      that = subber that, :contractions

      # Fetch 'topic'
      topic = @predicates[:topic]
      topic = subber topic, :contractions
      
      # Is it <star>?
      if element.name == "star"
        if element.attr('index')
          index = element.attr('index').to_i
        else
          index = 1
        end
          
        brain.star input, that, topic, "star", index			
      else 
         brain.star input, that, topic, "star", 1
      end
    end

    ##
    # Process <star>
    # can thatstar have an index?
    #
    def process_thatstar element, session_id
      # Get input
      input_stack = @session[session_id][:input_stack]
      input = input_stack[-1]

      # Set 'that'
      output_history = @session[session_id][:output_history]
      !output_history[-1].nil? ? that = output_history[-1] : that = "" 
      that = subber that, :contractions

      # Fetch 'topic'
      topic = @predicates[:topic]
      topic = subber topic, :contractions
      
      if element.attr('index')
        index = element.attr('index').to_i
      else
        index = 1
      end
      brain.star input, that, topic, "thatstar", 1
    end

    ##
    # Process <think>
    #
    def process_think element, session_id
      final_response = ""
      final_response	
    end

    ##
    # Process <sr>
    #
    def process_sr element, session_id
      star = process_star element, session_id
      respond star, session_id
    end

  end # // class
end # // module
