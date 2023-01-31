# Madeleine
> And suddenly the memory returns. The taste was
that of the little crumb of madeleine...

**- Marcel Proust** (In Search of Lost Time)

## Why?

A Ruby Set in memory isn't great for huge tasks. But a disk based Set is too slow for everything. We need the best of both worlds.

## What?

Data structures that use constant memory by spilling to disk after crossing a size threshold.

Currently the only supported data structure is `AppendSet`.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add madeleine

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install madeleine

## Usage
Add items to an `AppendSet`:
```ruby
append_set = Madeleine::AppendSet.new
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
[Source code available on Github](https://github.com/sutrolabs/madeleine). Feedback and pull requests are greatly appreciated. Let us know if we can improve this.

From
-----------
:wave: The folks at [Census](http://getcensus.com) originally put this together. Have data? We'll sync your data warehouse with your CRM and the customer success apps critical to your team.
