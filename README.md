# Blurrily — Millisecond fuzzy string matching

> Note: This fork is the UUID based version, see [mezis/blurrily](https://github.com/mezis/blurrily) for the original (amazing) integer based version.

[![Gem Version](https://badge.fury.io/rb/blurrily.svg)](http://badge.fury.io/rb/blurrily)
[![Build Status](https://travis-ci.org/mezis/blurrily.svg?branch=master)](https://travis-ci.org/mezis/blurrily)
[![Dependency Status](https://gemnasium.com/mezis/blurrily.svg)](https://gemnasium.com/mezis/blurrily)
[![Code Climate](https://codeclimate.com/github/mezis/blurrily.svg)](https://codeclimate.com/github/mezis/blurrily)
[![Coverage Status](https://coveralls.io/repos/mezis/blurrily/badge.png)](https://coveralls.io/r/mezis/blurrily)

> Show me photos of **Marakech** !
>
> Here are some photos of **Marrakesh**, Morroco.
> Did you mean **Martanesh**, Albania, **Marakkanam**, India, or **Marasheshty**, Romania?

Blurrily finds misspelled, prefix, or partial needles in a haystack of
strings, quickly. It scales well: its response time is typically 1-2ms on
user-input datasets and 75-100ms on pathological datasets
([more](#benchmarks)).

Blurrily is compatible and tested with all MRI Rubies from 1.9.3 to 2.2.0.
It is tested on Linux 2.6 (32bit and 64bit) and MacOS X 10.8.

Blurrily uses a tweaked [trigram](http://en.wikipedia.org/wiki/N-gram)-based
approach to find good matches. If you're using ActiveRecord and looking for
a lightweight (albeit much slower), in-process, Rails-friendly version of
this, check out [fuzzily](http://github.com/mezis/fuzzily), a Ruby gem to
perform fuzzy text searching in ActiveRecord.


## Installation

Add this line to your application's Gemfile:

    gem 'blurrily'

Or install it yourself as:

    $ gem install blurrily

## Docker

You can optionally run [Burrily as a Docker Container](https://github.com/mrmattwright/docker-blurrily). Maintained by [MrMattWright](https://github.com/mrmattwright).

## Usage

You can use blurrily as a client/server combination (recommended in
production), or use the internals standalone.

See the [API Documentation](http://rubydoc.info/github/mezis/blurrily/frames)
for more details.

### Client/server

Fire up a blurrily server:

    $ blurrily

Open up a console and connect:

  	$ irb -rubygems
  	> require 'blurrily/client'
  	> client = Blurrily::Client.new

Store a needle with a reference:
> **Note:** Support restricted to UUID v4, beginning with a non-zero ([Line 66 in libuuid](http://fossies.org/dox/e2fsprogs-1.42.13/uuid_2parse_8c_source.html) seems to be at fault?).

    > client.put('London', '10000000-0000-4000-A000-000000001337')

Recover a reference form the haystack:

    > client.find('lonndon')
    #=> ['10000000-0000-4000-A000-000000001337']

### Standalone

Create the in-memory database:

    > map = Blurrily::Map.new

Store a needle with a reference:

    > map.put('London', '10000000-0000-4000-A000-000000001337')

Recover a reference form the haystack:

    > map.find('lonndon')
    #=> ['10000000-0000-4000-A000-000000001337']

Save the database to disk:

    > map.save('/var/db/data.trigrams')

Load a previously saved database:

    > map = Blurrily::Map.load('/var/db/data.trigrams')


## Caveats

### Diacritics, non-latin languages

Blurrily forms trigrams from the 26 latin letters and a stop character (used
to model start-of-string and separation between words in multi-word
strings).

This means that case and diacritrics are completely ignored by Blurrily. For
instance, *Puy-de-Dôme* is strictly equivalent to *puy de dome*.

It also means that any non-latin input will probably result in garbage data
and garbage results (although it won't crash).

### Multi-word needles and edge stickyness.

Multi-word needles (say, *New York*) are supported.

The engine always favours matches that begin and end similarly to the
needle, with a bias to the beginning of the strings.

This is because internally, the string *New York* is turned into this
sequence of trigrams: `**n`, `*ne`, `new`, `ew*`, `w*y`, `*yo`, `yor`,
`ork`, `rk*`.

## Production notes

### Memory usage

Blurrily does not store your original strings but rather a flat map of
references and weights for each trigram in your input strings.

In practice any database will use up a base 560KB for the index header, plus
128 bits per trigram.

As a rule of thumb idea memory usages is 40MB + 8 times the size of your
input data, and 50% extra on top during bulk imports (lots of writes to the
database).

For instance, `/usr/share/dict/words` is a list of 235k English words, and
weighs 2.5MB. Importing the whole list uses up 75MB of memory, 51MB of which
are the database.

Note that once a database has been written to disk and loaded from disk,
memory usage is minimal (560KB per database) as the database file is memory
mapped. For performance you do need as much free memory as the database
size.

### Disk usage

Disk usage is almost exactly like memory usage, since database files are
nothing more than a memory dump.

In the `/usr/share/dict/words` example, on-disk size is 51MB.
For the whole list of Geonames places, on-disk size is 1.1GB.

### Read v write

Writing to blurrily (with `#put`) is fairly expensive—it's a search engine
after all, optimized for intensive reads.

Supporting writes means the engine needs to keep a hash table of all
references around, typically weighing 50% of your total input. This is build
lazily while writing however; so if you load a database from disk and only
ever read, you will not incur the memory penalty.

### Saving & backing up

Blurrily saves atomically (writing to a separate file, then using rename(2)
to overwrite the old file), meaning you should never lose data.

The server does this for you every 60 seconds and when quitting. If using
`Blurrily::Map` directly, remember that a map loaded from disk is more
memory efficient that a map in memory, so if your workload is read-heavy,
you should `.load` after each `#save`.

Backing up comes with a caveat: database files are only portable across
architectures if endianness and pointer size are the same (tested between
darwin-x86_64 and linux-amd64).

Database files are very compressible; `bzip2` typically shrinks them to 20%
of their original size.

## Benchmarks

Blurrily is wicked fast, often 100x faster than it's ancestor,
[fuzzily](http://github.com/mezis/fuzzily). This is because it's a close-to-
the-metal, single-purpose index using almost exclusively libc primitives. On
the inside the only expensive operations it performs are

- memcpy(2) lots of data around (selection);
- mergesort(3) to aggregate/count similar entries (reduction);
- qsort(3) to order by counts (sort).

It tends to be faster with large datasets on BSD than on Linux because the
former has fast quicksort and mergesort, wheras the latter only has `qsort`,
a slower, catch-all sorter. In complexity terms this is because FIND tends
to be *O(n)* on BSD and *O(n ln n)* on Linux.

Enough talk, here are the graphs. The `LOAD` and `PUT` operations are O(1)
and take respectively ~10ms and ~100µs on any platform, so  they aren't
graphed here.

- [FIND latency](/doc/bench-find.png)
- [SAVE latency](/doc/bench-save.png)
- [DELETE latency](/doc/bench-delete.png)


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
