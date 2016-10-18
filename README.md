
# solidus jmeter

A [ruby-jmeter](https://github.com/flood-io/ruby-jmeter) script for a performance test of the solidus checkout flow.

## Setup

You need jmeter 3 along with the new [Plugins Manager](https://jmeter-plugins.org/wiki/PluginsManager/) installed in your `$PATH`, and the following plugins need to be installed:

- "3 Basic Graphs"
- "JSON Plugins"

Under OSX, this can be accomplished by simply running
```
brew install jmeter --with-plugins
```

At this point, start a sandbox in a different terminal, and then do:

```
bundle
bundle exec ruby testplan.rb
```

Pro Tip: No SQLite with performance testing. It's not good for that.
