require File.expand_path '../test_helper.rb', __FILE__

class KernelTest < MiniTest::Test

	def setup
    @bot = Programb::Kernel.new
	  @bot.learn("test/aiml")
  end
  
	def test_bixsby_can_learn_aiml
    skip
		filename = "test/aiml"
		assert bot.learn(filename)
	end

  def test_bicxsby_can_respond_to_system_tag
    skip "system currently broken"
  end

  def test_bixsby_can_respond_to_bot_tag
    bot_result = @bot.respond "TEST BOT"
		assert_equal "My name is #{@bot.properties['name']}", 
      bot_result, "[ERROR] Bot test failed!"
  end

  def test_bixsby_can_respond_to_date_tag
		date_result = @bot.respond "TEST DATE"
		assert_equal "The date is #{Time.now.strftime('%A %B %d, %Y %H:%M%p')}", 
        date_result, "Date test failed!"
  end

  def test_bixsby_can_respond_to_uppercase_tag
		uppercase_result = @bot.respond "TEST UPPERCASE"
		assert_equal "The Last Word Should Be #{'Uppercase'.upcase}", 
      uppercase_result, "Uppercase test failed!"
  end
  
  def test_bixsby_can_respond_to_lowercase_tag
    lowercase_result = @bot.respond "TEST LOWERCASE"
    assert_equal "The Last Word Should Be #{'LOWERCASE'.downcase}", 
      lowercase_result, "Lowercase test failed!"
  end
  
  def test_bixsby_can_respond_to_sentence_tag
    sentence_result = @bot.respond "TEST SENTENCE"
    assert_equal "The first letter should be capitalized", 
      sentence_result, "Sentence test failed!"
  end

  def test_bixsby_can_respond_to_think_tag
    think_result = @bot.respond "TEST THINK"
    assert_equal "", think_result, "Think test failed!"
  end
  
  def test_bixsby_can_respond_to_set_tag
    @bot.respond "TEST SET"
		assert_equal "Testing", @bot.predicates[:topic], "Set test failed!"
  end

  def test_bixsby_can_respond_to_get_tag
    @bot.respond "TEST SET"
    get_result = @bot.respond "TEST GET"
    assert_equal "The current topic is Testing", get_result, "Get test failed!"
  end

  def test_bixsby_can_respond_to_size_tag
    size_result = @bot.respond "TEST SIZE"
    assert_equal "I've learned 54 categories", 
      size_result, "Size test failed!"
  end

  def test_bixsby_can_respond_to_srai_tag
    srai_result = @bot.respond "TEST SRAI"
    assert_equal "srai test passed", srai_result, "Srai test failed!"
  end
  
  def test_bixsby_can_respond_to_formal
    formal_result = @bot.respond "TEST FORMAL"
    assert_equal "Formal Test Passed", 
      formal_result, "Formal test failed!"
  end

  def test_bixsby_can_respond_to_condition
    condition_result = @bot.respond "TEST CONDITION NAME VALUE"
    assert_equal "You are handsome", condition_result, "Condition test failed!"
  end

  def test_bixsby_can_respond_to_condition_1
    condition_result = @bot.respond "TEST CONDITION NAME"
    assert_equal "You are handsome", condition_result, "Condition 1 test failed!"
  end

  def test_bixsby_can_respond_to_condition_2
    skip
    condition_result = @bot.respond "TEST CONDITION"
    assert_equal "You are handsome", condition_result, "Condition 2 test failed!"
  end

  def test_bixsby_can_respond_to_person_tag
    person_result = @bot.respond "TEST PERSON"
    assert_equal "I think he knows that my actions threaten him and his", 
      person_result, "Person test failed!"
  end
  
  def test_bixsby_can_respond_to_person_star_tag
    person_result = @bot.respond "TEST PERSON BOY"
    assert_equal "I think boy knows.", 
      person_result, "Person atmoic test failed!"
  end

  def test_bixsby_can_respond_to_person2_tag
    person2_result = @bot.respond "TEST PERSON2"
    assert_equal "you think you know that my actions threaten me and yours", 
      person2_result, "Person2 test failed!"
  end

  def test_bixsby_can_respond_to_person2_star_tag
			person2_star_result = @bot.respond "TEST PERSON2 STAR"
			assert_equal "star", person2_star_result, "Person2 Star test failed!"
  end

  def test_bixsby_can_respond_to_gender_tag
    gender_result = @bot.respond "TEST GENDER"
    assert_equal "He is really a she", gender_result, "Gender test failed!"
  end

  def test_bixsby_can_respond_to_id_tag
    id_result = @bot.respond "TEST ID"
    assert_equal "Your id is #{@bot.session.keys[0]}", id_result, "Id test failed!"
  end

  def test_bixsby_can_respond_to_input_tag
    input_result = @bot.respond "TEST INPUT"
    assert_equal "You just said: test input", input_result, "Input test failed!"
  end

  def test_bixsby_can_respond_to_random_tag
    random_result = @bot.respond "test random"
    if random_result == "response #1" || 
      random_result == "response #2" || 
      random_result == "response #3"
				true
		else
			raise "Random Test failed!"
		end
  end

  def test_bixsby_can_respond_to_sr_tag
    sr_result = @bot.respond "TEST SR TEST BOT"
    assert_equal "srai results: My name is Bixsby", 
      sr_result, "SR test failed!"
  end

  def test_bixsby_can_respond_to_nested_sr_tag
    sr_nested_result = @bot.respond "TEST NESTED SR TEST BOT"
    assert_equal "srai results: My name is Bixsby", 
      sr_nested_result, "Nested SR test failed!"
  end

  # Star Tests
  def test_bixsby_can_respond_to_star_begining
    star_at_begining = @bot.respond "HELLO TEST STAR BEGIN"
    assert_equal "Begin star matched: hello", 
      star_at_begining, "Beginning Star test failed!"
  end

  def test_bixsby_can_respond_to_star_middle
    star_in_middle = @bot.respond "TEST STAR HELLO MIDDLE"
    assert_equal "Middle star matched: hello", 
      star_in_middle, "Middle Star test failed!"
  end

  def test_bixsby_can_respond_to_star_end
    star_at_end = @bot.respond "TEST STAR END HELLO"
    assert_equal "End star matched: hello", star_at_end, "End Star test failed!"
  end

  def test_bixsby_can_respond_to_multi_star
    multi_star_result = @bot.respond "TEST STAR HERE MULTIPLE TIMES MAKES ME HAPPY"
    assert_equal "Multiple stars matched: here, times, happy", 
      multi_star_result, "Multiple Star test failed!"
  end

  # That tests
  def test_bixsby_can_respond_to_that_tag			
    @bot.respond "TEST THAT"
    that_result = @bot.respond "TEST THAT"
    assert_equal "I have already answered this question", 
      that_result, "That test failed!"
  end

  def test_bixsby_can_respond_to_thatstar_tag 
    @bot.respond "TEST THATSTAR"
    thatstar_result = @bot.respond "TEST THATSTAR"
    assert_equal "I just said 'beans'", thatstar_result, "Thatstar test failed!"
  end

  def test_bixsby_can_respond_to_thatstar_multi
    skip
    @bot.respond "TEST THATSTAR MULTIPLE"
    multi_thatstar_result = @bot.respond "TEST THATSTAR MULTIPLE"
    assert_equal "Yes, beans and franks for all!", 
      multi_thatstar_result, "Multi-Thatstar test failed!"
  end

  # Topic Tests
  def test_bixsby_can_respond_to_topic
    @bot.respond "TEST SET"
    topic_result = @bot.respond "TEST TOPIC"
    assert_equal "We were discussing 'testing'", 
      topic_result, "Topic test failed!"
  end

  def test_bixsby_can_respond_to_version
    version_result = @bot.respond "TEST VERSION"
    assert_equal "ProgramB is version #{Programb::VERSION}", 
      version_result, "Version test failed!"
  end
		
end
