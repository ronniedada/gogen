# Configuring Gogen

Gogen is the spiritual successor to my original [Eventgen](https://github.com/splunk/eventgen), and as such it shares many configuration concepts in common.  However, Gogen as the successor has been designed to work around a number of deficiencies in Eventgen's original configuration format.  

Gogen was designed to be configured from a single file.  This makes moving configurations around very simple.  Managing the data Gogen references is painful from a single file, so it also allows for referencing other files.  For example, choice token types allow choosing items from fields in other samples, and these samples can be referenced to files on the file system.  When publishing the configurations, Gogen will take it's in-memory representation which has joined all the configuration data together, and generate a single file version of this configuration.  Later, if desired, Gogen can deconstruct this single file representation back into component files to make editing easier.

## Config File Overview

Gogen is configured via a YAML or JSON based configuration.  Lets look at a very simple example configuration:

    samples:
      - name: tutorial1
        interval: 1
        endIntervals: 5
        count: 1
        randomizeEvents: true
        
        tokens:
        - name: ts
          format: template                                                                                                                     
          type: timestamp
          replacement: "%b/%d/%y %H:%M:%S"

        lines:
        - _raw: $ts$ line1
        - _raw: $ts$ line2
        - _raw: $ts$ line3

This example is in YAML.  Gogen configurations are made up of Samples, which contain some configuration, tokens, and lines.  In this example, we will generate 1 event (`count: 1`) from a random line (`randomizeEvents: true`) every 1 second (`interval: 1`) for a total of 5 intervals (`endIntervals 5`).  When `endIntervals` is set, we will go back that number of intervals and just work as fast as we can to generate that number of events.  Gogen can also keep generating and generate in realtime, which we'll cover a bit later.  

You can see we define here a top level item called samples, which is a list of objects.  There are a few top level directives which control Gogen:

| Section    | Description                                                                                                        |
|------------|--------------------------------------------------------------------------------------------------------------------|
| global     | Defines global parameters, such as output                                                                          |
| generators | Defines custom generators, written in Lua, which can greatly extend gogen's capabilities                           |
| raters     | Defines raters, which allow you to rate the count of events or value of tokens based on time or custom Lua scripts |
| samples    | Define sample configurations, which is the core data structure in Gogen                                            |
| mix        | Defines mix configurations, which allow you to reuse existing sample configurations in new configurations          |
| templates  | Defines output templates, which allow you to format the output of Gogen using Go's templating language             |

We will cover these in future examples.

To run this example, from the Gogen repo directory:

    gogen -c examples/tutorial/tutorial2.yml gen

## Raters & Scripts

Two of the most important concepts in Gogen are the concepts of rater and scripts.  Raters the user to modify the count of events or the value of tokens based on the time. Scripts allow the user the extend Gogen's logic through simple [Lua](http://lua.org/) scripts. Lets see this in action.

    raters:
      - name: eventrater
        type: config
        options:
        MinuteOfHour:
            0: 1.0
            1: 0.5
            2: 2.0
      - name: valrater
        type: script
        script: >
            return options["multiplier"]
        options:
            multiplier: 2
    
    samples:
      - name: tutorial2
        begin: 2012-02-09T08:00:00Z
        end: 2012-02-09T08:03:00Z
        interval: 60
        count: 2
        rater: eventrater

        tokens:
          - name: ts
            format: template                                         
            type: timestamp
            replacement: "%b/%d/%y %H:%M:%S"
          - name: linenum
            format: template
            type: script
            init:
              id: "0"
            script: >
              state["id"] = state["id"] + 1
              return state["id"]
          - name: val
            format: template
            type: random
            replacement: int
            lower: 1
            upper: 5
          - name: rated
            format: template
            type: rated
            replacement: int
            lower: 1
            upper: 3
            rater: valrater

        lines:
        - _raw: $ts$ line=$linenum$ value=$val$ rated=$rated$

Go ahead and run this.

    gogen -c examples/tutorial/tutorial2.yml gen

Let's examine this config in detail, because it introduces a number of important concepts.  First, this config, rather than running over a specified number of intervals, is setup to run over a specific time period by setting the `begin` and `end` clauses of the sample.  It is set to generate `count: 2` events, once per minute, with an `interval` of `60`.  Lastly, it sets a rater of `eventrater`, which we will explain in detail.

There are two types of raters, `config` and `script`.  The last, `default`, always returns 1.  Raters return a value to _multiply_ events by.  If an event has a count of 2, it'll be multiplied by the value returned by the `eventrater` rater.  The `config` rater will rate events by the time of the event.  In this case, the event will always be between 8 AM and 8:03 AM, so we've only set a few `MinuteOfHour` options, but canonically [it will look more like this](tests/rater/configrater.yml).  The `config` rater has three options, `MinuteOfHour`, `HourOfDay` and `DayOfWeek`.  It will look up the current time of the event in each of these three options, and if found, multiply the `count` (set by `count` in the event) by this floating point value, and once all the multiplications are done, round to the nearest whole number.

In our example, we should see 2 events generated in the first minute, 1 event in the second minute, and 4 events in the last minute.  

Now, lets look at the tokens for this sample.  The first token introduces a custom script token.  This script is written in [Lua](http://lua.org/), which is very [easy to learn](https://www.lua.org/pil/1.html).  Most people who are versed in scripting or programming can pick up Lua merely by modifying the examples provided with Gogen.  The `linenum` token is very simple, as all it does is return a monotonically increasing identifier to be used as our line number.  Useful, but simple.  It's initialized with the `init` configuration directive, to create an entry in the `state` table in Lua under the `id` item, and set it to zero.  The script increments this id and returns the value on every iteration.

The other two tokens show the difference between a random token and a rated token.  Both are configured nearly identically.  `val` and `rated` both have a `replacement` of int, a `lower` and `upper` configuration directive dictating the value ranges to be generated.  The difference is `rated` is run through a rater first, the same way event counts are, by multiplying the random value from the token times the value returned by the rater.  In this case, the rater is a simple script, which looks up a value configured in `options` in the YAML and returns that value as the multiplier.

This example is much more complicated than the original, but begins to show off the true power of what Gogen can do with easy to understand and share configurations.

## Tokens & the power of sample files

Gogen was enhanced to include the easy addition of custom scripts to enhance the base functionality, but the core ability of Gogen is still its ability to generate real-looking data by simply subtituting data randomly from lists of options.  Eventgen had this capability, and Gogen has *significantly* enhanced it by making it much easier to manage and configure.

Tokens have two different `format` options, `regex` and `template`.  `regex` will search a line for a regex pattern and replace any matches with the value from the token.  `template` is *far* preferred and *significantly more performant*, and it will replace, by default, a token matching `$<name>$` in the original event.  Template is intended if you're manually crafting an event, no need to waste the CPU cycles to do regex matches when a simple string match will do.  If you have a token named `foo`, it will search for the text `$foo$` in the original event and replace that.

Tokens also have a number of `type` settings.  See the [Reference manual](README/Reference.md) for a full list, but the primary categories are `timestamp`, `static`, `random`, `rated`, `choice` (with `fieldChoice` and `weightedChoice`) and `script`.  Most important are the `choice` settings, and thusly the section about sample files.  Choice settings can be determined by bringing in data from external files.  Lets examine tutorial 3 in more detail for some examples:

    name: tutorial3
    begin: 2012-02-09T08:00:00Z
    end: 2012-02-09T08:03:00Z
    interval: 60
    count: 2
    rater: eventrater
    tokens:
      - name: ts
        format: regex
        token: (\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2},\d{3})
        type: gotimestamp
        replacement: "2006-01-02 15:04:05.000"
      - name: host
        format: template
        type: choice
        field: host
        choice:
        - server1.gogen.io
        - server2.gogen.io
      - name: transtype
        format: regex
        token: transType=(\w+)
        type: weightedChoice
        weightedChoice:
        - weight: 3
          choice: New
        - weight: 5
          choice: Change
        - weight: 1
          choice: Delete
      - name: integerid
        format: template
        type: script
        init:
          id: "0"
        script: >
          state["id"] = state["id"] + 1
          return state["id"]
      - name: guid
        format: template
        type: random
        replacement: guid
      - name: username
        format: template
        type: choice
        sample: usernames.sample
      - name: markets-city 
        format: template
        token: $city$
        type: fieldChoice
        sample: markets.csv
        srcField: city
        group: 1
      - name: markets-state 
        format: template
        token: $state$
        type: fieldChoice
        sample: markets.csv
        srcField: state
        group: 1
      - name: markets-zip
        format: template
        token: $zip$
        type: fieldChoice
        sample: markets.csv
        srcField: zip
        group: 1
      - name: value
        format: regex
        token: value=(\d+)
        type: random
        replacement: float
        precision: 3
        lower: 0
        upper: 10

    lines:
      - index: main
        host: $host$
        sourcetype: translog
        source: /var/log/translog
        _raw: 2012-09-14 16:30:20,072 transType=ReplaceMe transID=$integerid$ transGUID=$guid$ userName=$username$ city="$city$" state=$state$ zip=$zip$ value=0

To run this tutorial run:

    gogen -cd examples/tutorial/tutorial3 -ot json gen

The first thing to note about this config: no samples item.  All the items from the sample are top level directives.  This is because we're running this config as a [config directory](examples/tutorial/tutorial3) instead of a [full config](examples/tutorial/tutorial2.yml), thusly running `gogen -cd` instead of `gogen -c`.  Config directories allow for breaking out out of the items to be managed into individual files instead of being combined into one.  This allows, for example, to share raters amongst samples without copying and pasting them amongst the full config files.  In this case, we have subdirectories inside the config directory called `samples` and `raters` which contain the same items which would be list items of a full config seperated into their own files.  Gogen will walk that directory and load anything with an extension of `yml`, `json`, `csv`, or `sample`.  When we want to share this config, Gogen allows for export functions which will combine all these files into a single file config for sharing.

The next thing to note about this config is that we've added support for multiple fields in the sample's lines.  This is why we suggested the `-ot json` directive in the command line.  This sets the `outputTemplate` to `json`, which can also be specified in the `global` directive.  `json` will show you easily there is multiple fields of metadata flowing through the gogen event, but by default only `_raw` is output, matching with how Splunk treats data.

Now, let's look through the tokens to better understand a more complicated token configuration.  Firstly, if we look at the timestamp token, it is using a `regex` match, which we normally don't do in this type of example except to show how it's done.  Note with the regex, we need to ensure we have a capture group in parenthesis to tell Gogen where to replace.  This timestamp uses [Go's time format syntax](https://gobyexample.com/time-formatting-parsing), which uses a reference time of `Mon Jan 2 15:04:05 MST 2006`.  When you want a timestamp to look like `%Y-%m-%d %H:%M:%S` in strftime format, you would give gotimestamp `2006-01-02 15:04:05`.  It takes a bit of getting used to, but it's significantly more performant than strftime, so it's recommended to use this format.

Next is the `host` token.  This introduces two new options, the first is a type of `choice`.  `choice` tokens choose from a list of items to get the value from which to substitute.  In this case, we've articulated the values right in the configuration, but `choice`, `fieldChoice` and `weightedChoice` tokens can also get their values from external sample files in flat text file or csv format, which you can see in the `username` token further down.  Lastly, it's important to note the `field` directive, which substitutes `host` into the `host` field of the sample line.  Field can be declared on any token to tell it to replace items in any field in the event, with the default being to replace in `_raw`.

The next token we want to look at is `transtype`.  `transtype` is of type `weightedChoice`, which chooses tokens based on a weighting algorithm.  A token of weight `5` will be 5 times more likely to be chosen than a token of weight `1`.  This is very helpful when trying to model data that looks more like real world data, which isn't necessarily going to have an even distribution.  

Next, lets take a look at a series of tokens, the ones prefixed with markets.  These tokens introduce a new type, `fieldChoice`, and a few new directives, `srcField` and `group`.  `fieldChoice` tokens will select a replacement from a field from a tablular dataset, like a CSV or a list of YAML objects.  What makes these even more useful, is that the choice we make can be carried across multiple token substitutions.  This is what the `group` clause is for, and it can be used in any of the choice token types.  Any time a `group` clause is present, the same choice will be used across any matched group number.  

## Generators & Templates

As I was rewriting the original Eventgen concept that was to become Gogen, I really wanted to preserve the original concept I had built into Eventgen later of expandability.  Eventgen allows users to ship custom generators in their Eventgens, so I wanted to replicate that in Gogen.  We do that through custom Lua generators, which have a rich API to allow the Lua scripts to interact with Gogen.  This allows for higher performance, as most of the work is handled in Go code, and it allows for the script developer to minimize the amount of things they need to replicate in their own code.

Secondly, I wanted the ability to customize how we output data.  Making that format expandable will future proof Gogen, and allow field expandability to model new types of data formats.  Gogen can output raw text, JSON, CSV and other formats by default, but custom templates allow for more complicated data structures.

For the next example, we're going to show both of these features generating an ini-style configuration file just for giggles.

 

TODO:
* Single JSON Document using templates
* Simple replay
* Custom Generator