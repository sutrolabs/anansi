# frozen_string_literal: true

require "test_helper"

class AppendSetTest < Minitest::Test
  def setup
    @append_set = Anansi::AppendSet.new
  end

  def test_any
    assert_equal false, @append_set.any?

    @append_set.add(["foo"])

    assert_equal true, @append_set.any?
  end

  def test_that_it_has_a_version_number
    refute_nil ::Anansi::VERSION
  end

  def test_size
    assert_equal 0, @append_set.size

    @append_set.add(["foo"] * 100)

    assert_equal 1, @append_set.size

    @append_set.add(100.times.map(&:to_s))

    assert_equal 101, @append_set.size
  end

  def test_include
    assert_equal false, @append_set.include?("x")
    @append_set.add ["x"]
    assert_equal true, @append_set.include?("x")
  end

  def test_include_with_non_string
    @append_set.add [1]
    assert_equal true, @append_set.include?(1)

    @append_set.add [false]
    assert_equal true, @append_set.include?(false)

    @append_set.add([{ foo: :bar }])
    assert_equal true, @append_set.include?(foo: :bar)
    assert_equal false, @append_set.include?(foo: "bar")
  end

  def test_spill
    count = Anansi::AppendSet::SPILL_THRESHOLD + 1
    @append_set.add(count.times)
    assert_equal count, @append_set.size
    assert_equal true, @append_set.include?(0)
    assert_equal false, @append_set.include?(count)
    assert_equal true, @append_set.any?
  end
end
