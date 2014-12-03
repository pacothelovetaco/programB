require 'nokogiri'
require 'logger'

module Programb
  class Graphmaster

    #include MiniTest::Assertions

    # The Graphmaster creates Bixby's memory banks. By following the rules described
    # by Dr. Richard Wallace, http://www.alicebot.org/documentation/matching.html,
    # the Graphmaster first maps AIML into nodes. The nodes are organized following
    # three rules:
    # 	1: Does the Nodemapper contain the key "_"
    # 	2: Does the Nodemapper contain the key "X"
    #   3: Does the Nodemapper contain the key "*" 

    attr_accessor :template_count, :category_count, :nodemap

    
    
    LOGGER = "[#{Time.now.strftime('%H:%M:%S')}][GRAPHMASTER]"
    
    def initialize(log)     
      @log = log
      @template_count = 0
      @category_count = 0
      @nodemap = {}

      if @log then @log.info("Loading Graphmaster") end
    end

    ##	
    # Parses AIML and creates 'nodes' for patterns and their templates 
    # in the @nodemap. Constants are defined to help organize and speed up
    # node lookup for a user's input.
    # For more info, see http://www.alicebot.org/documentation/matching.html.
    # 
    # @author Justin Leavitt
    #
    # @param
    #   pattern   [Nokogiri::XML::Node] pattern sent from the current category
    #   template  [Nokogiri::XML::Node] template sent from the current category
    #   that      [Nokogiri::XML::Node] that sent from the current category
    #   topic     [Nokogiri::XML::Node] topic sent from the current category
    #
    UNDERSCORE	= 0
    STAR				= 1
    TEMPLATE 		= 2
    THAT 				= 3
    TOPIC				= 4
    BOT_NAME   	= 5 
    #
    # @return [Hash] the nodemap
    def map(pattern, template, that=nil, topic=nil)
      
      if !pattern.nil?
        @category_count += 1
      end

      node = @nodemap 
      
      # Split the pattern into an array
      words = pattern.text.split(" ")
      
      # Loop through each word, organize and add to the @nodemap.
      words.each do |key|
        if key == "_"
          key = UNDERSCORE

        elsif key == "*"
          key = STAR

        elsif key == BOT_NAME
          key = BOT_NAME
        end				
        if !node.has_key?(key) 
          node[key] = {}
        end
        node = node[key]
      end

      # Add <that> if it exists.
      if that != nil
        if !node.has_key?(THAT)
          node[THAT] = {}
        end
        node = node[THAT]
        
        words = that.text.split(" ")
        
        words.each do |key|
          if key == "_"
            key = UNDERSCORE
          elsif key == "*"
            key = STAR
          end
          if !node.has_key?(key)
            node[key] = {}
          end
          node = node[key]
        end
      end

      # Add <topic> if it exists.
      if topic != nil
        if !node.has_key?(TOPIC)
          node[TOPIC] = {}
        end
        node = node[TOPIC]
        
        # The topic is a string and not XML
        words = topic.split(" ")

        words.each do |key|
          if key == "_"
            key = UNDERSCORE
          elsif key == "*"
            key = STAR
          end
          if !node.has_key?(key)
            node[key] = {}
          end
          node = node[key]
        end
      end

      # Add the template
      if !node.has_key?(template)
        @template_count += 1
        node[TEMPLATE] = template#.inner_html
      end
    end

    ##
    # Recursively searches the @nodemap, looking for a match to
    # the user's input. This method first normalizes the parameters, then 
    # passes that data to the recursive_match method.
    #
    # @author Justin Leavitt
    # 
    # @param
    #   pattern [String] user's input to match
    #   that    [String] the current 'that'
    #   topic   [String] the current 'topic'
    #
    # @return 
    #   [Nokogiri::XML::Node] the 'template' to the matching pattern
    def match pattern, that, topic

      # Make pattern uppercase and strip punctuation
      input = pattern.to_s.upcase
      input = input.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip

      # Normalize 'that' 
      formatted_that = that.to_s.upcase
      formatted_that = formatted_that.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip

      # Normalize 'topic'
      formatted_topic = topic.to_s.upcase
      formatted_topic = formatted_topic.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip
      
      if $VERBOSE
        if @log then @log.debug "#{'='*80} \n INPUT: #{input} \n THAT:  #{formatted_that} \n TOPIC: #{formatted_topic}\n" end
      end

      # Pass input to recursive pattern-matcher
      match, template = recursive_match(input.split(" "), formatted_that.split(" "), formatted_topic.split(" "), @nodemap)
      
      template
    end

    ##
    # Does all the heavy lifting. Recursively searches nodemapper and pulls
    # out the template from the matching node. The method requires the user's input as
    # an array. The first word is matched at the highest level of the @nodemap
    # hash. If a match is found, the method is called again, passing the matching 'key' and values
    # as the 'node' parameter. The method continues this process until it has found
    # a the first exact match to each word in the user's input.
    #
    # @example
    #   If this is the current: {"THIS" => {"IS" => {"A" => {"PATTERN" => {2 => <template>This is the response.</template>}}}}}
    #   and the user inputs "THIS IS A PATTERN", "THIS" gets matched, then the method
    #   calls itself again, passing in "IS" as the 'word' and "THIS"["IS"] as the node.
    #   this process is continued until there are no more words to match, and the template is returned.
    # 
    # @params
    #   words [Array] the user input split into an array
    #   that  [String] the current 'that'
    #   topic [String] the current 'topic'
    #   node  [Hash] The collection of Bixby's responses
    #   
    # @returns
    #   pattern  [Nokogiri::XML::Node] the matching pattern
    #   template [Nokogiri::XML::Node] the template for the matching pattern
    #
    # @TODO
    #  Fixup the documentation on this method: It needs a more robust exp.
    def recursive_match(words, that, topic, node) 

      # Terminal case: 
      # There are no more words, return template
      if words.count == 0
        pattern = []
        template = nil

        if that.count > 0
          # If that is empty and topic isn't, recursively pattern
          # on TOPIC node with topic as input
          begin
            pattern, template = recursive_match that, [], topic, node[THAT]

            if pattern != nil
              pattern = [THAT] + pattern
            end
          rescue
            if topic.count > 0
              # If that has no match and topic isn't empty, recursively pattern
              # on TOPIC node with topic as input
              begin
                pattern, template = recursive_match topic, [], [], node[TOPIC]

                if pattern != nil
                  pattern = [TOPIC] + pattern
                end
              rescue
                pattern = []
                template = nil
              end
            end
          end
        end
        
        # We are officially out of input. Return the template.		
        if template == nil
          pattern = []
          begin
            template = node[TEMPLATE]
          rescue
            template = nil
          end
        end
        return pattern, template
      end

      # Find first and subsequent words in the array
      first = words[0]
      suffix = words[1..-1]

      #First Rule: Search _ first
      if node.has_key?(UNDERSCORE)
        for i in 0..suffix.count
          suf = suffix[i..-1]
          pattern, template = recursive_match suf, that, topic, node[UNDERSCORE]
          if template != nil
            new_pattern = [UNDERSCORE] + pattern
            #puts Kernel.cyan("#{new_pattern}, #{template}") if $VERBOSE
            @log.debug("#{new_pattern}, #{template}") if $VERBOSE && @log
            return new_pattern, template
          end
        end
      end

      # Second Rule: Find template if node matches first word
      if node.has_key?(first)
        pattern, template = recursive_match suffix, that, topic, node[first]
        if template != nil
          new_pattern = [first] + pattern
          #puts Kernel.cyan("#{new_pattern}, #{template}") if $VERBOSE
          @log.debug("#{new_pattern}, #{template}") if $VERBOSE && @log
          return new_pattern, template
        end
      end

      # Third Rule: Search * last
      if node.has_key?(STAR)
        for i in 0..suffix.count
          suf = suffix[i..-1]
          pattern, template = recursive_match suf, that, topic, node[STAR]
          if template != nil
            new_pattern = [STAR] + pattern
            #puts Kernel.cyan("#{new_pattern}, #{template}") if $VERBOSE
            @log.debug("#{new_pattern}, #{template}") if $VERBOSE && @log
            return new_pattern, template
          end
        end
      end

      # We found nothing, return nil
      return nil, nil
    end
    
    ##
    # Processes a pattern that has a '*' element.
    # 
    # @params
    #   pattern [String] user's input to match
    #   that    [String] the current 'that'
    #   topic   [String] the current 'topic'
    #   type    [String] the type of star (star, thatstar, or topicstar)
    #   index   [Integer] the location of the star
    #
    # @returns 
    #   [String] the words from the input that matches the star location (index)
    def star(pattern, that, topic, type, index)
      input = pattern.to_s.upcase
      input = input.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip

      # Normalize 'that'  
      formatted_that = that.to_s.upcase
      formatted_that = formatted_that.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip

      # Normalize 'topic'
      formatted_topic = topic.to_s.upcase
      formatted_topic = formatted_topic.gsub(/(?=\S)(\W)/, " ").squeeze(" ").strip

      match, template = recursive_match input.split(" "), formatted_that.split(" "), formatted_topic.split(" "), @nodemap

      return "" if template == nil


      # Find appropriate pattern based on the star type.
      words = nil
      if type == 'star'
        #match = match[0..match.index(THAT)]
        words = input.split(" ")
      
      elsif type == 'thatstar'
        match = match[(match.index(THAT)+1)..match.index(STAR)]
        words = that.split(" ")
      
      elsif type == 'topicstar'
        match = match[(match.index(TOPIC)+1)..-1]
        words = topic.split(" ")
      
      else
        raise "Star Type must be in ['star', 'thatstar', 'topicstar']"
      end
      
      # compare the input string to the matched pattern, word by word.
      # At the end of this loop, if found_star is true, start and
      # end will contain the start and end indices (in "words") of
      # the substring that the desired star matched.
      
      found_star = false
      start = last = j = num_stars = k = 0
      
      for i in (0...words.count)
        # This condition is true after processing a star
        # that ISN'T the one we're looking for.
        next if i < k

        # If we're reached the end of the pattern, we're done.
        break if j == match.count

        if not found_star
          if [STAR, UNDERSCORE].include?(match[j]) #we got a star
            num_stars += 1
            
            # This is the star we care about.
            found_star = true if num_stars == index
            
            # Iterate through the rest of the string.
            start = i
            for k in (i...words.count)
              # If the star is at the end of the pattern,
              # we know exactly where it ends.
              if j+1 == match.count
                last = words.count
                break
              end
              # If the words have started matching the
              # pattern again, the star has ended.
              if match[j+1] == words[k]
                last = k - 1
                i = k
                break
              end
            end
          end
          # If we just finished processing the star we cared
          # about, we exit the loop early.
          break if found_star
        end
        # Move to the next element of the pattern.
        j += 1
      end
        
      # extract the star words from the original, unmutilated input.
      if found_star
        if type == 'star'
          response = pattern.split(" ")
          response = response[start..last]
          return response.join(" ")
        
        elsif type == 'thatstar'
          response = that.split(" ")
          response = response[start..last]
          return response.join(" ")

        elsif type == 'topicstar'
          response = topic.split(" ")
          response = response[start..last]
          return response.join(" ")
        end
      else 
        return ""
      end
    end

  end # // class
end # // module
