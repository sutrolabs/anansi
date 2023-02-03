# Anansi - A hybrid Ruby Set using memory and Disk (using sqlite3) for large sized tasks

> He lifted the pot over his head and threw it on the ground. The pot crashed on the ground and the wisdom blew far and wide all over the earth. And this is how wisdom came to the world (or your disk).

**- Kiren Babal** ([Anansi and the Wisdom Pot](https://www.differenttruths.com/literature/short-story/anansi-and-the-wisdom-pot/))

## Why?

A Ruby Set in memory isn't great for huge tasks. But a disk based Set is too slow for everything. We need the best of both worlds.

## What?

Data structures that use constant memory by spilling to disk after crossing a size threshold.

Currently the only supported data structure is `AppendSet`.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add anansi

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install anansi

## Usage
Add items to an `AppendSet`:
```ruby
append_set = Anansi::AppendSet.new
append_set.add(['foo', 'bar', 'buzz'])
```

Check if an item exists in an `AppendSet`:
```ruby
append_set.include? 'foo'
```

Get the size of an `AppendSet`:
```ruby
append_set.size
```

(If you need other data structures, stay tuned and [watch our org](https://github.com/sutrolabs).)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Feedback
--------
[Source code available on Github](https://github.com/sutrolabs/anansi). Feedback and pull requests are greatly appreciated. Let us know if we can improve this.

From
-----------
:wave: The folks at [Census](http://getcensus.com) originally put this together. Have data? We'll sync your data warehouse with your CRM and other apps critical to your team. Interested in what we do? **[Come work with us](https://www.getcensus.com/careers)**.
