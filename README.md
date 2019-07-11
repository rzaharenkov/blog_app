# README

This is sample Rails app to demonstrate how to use ruby internal in order to optimize caching.

## Problem

When you cache data in memcached (I'd assume you use dalli gem) it's usually serialized with `Marshal.dump / Marshal.load`. This method is good default and it's relyable but it's not optimal. It dumps all the instance variables of any object. In addition to record attributes ActiveRecord stores a lot metadata for each object (e.g. validation errors, dirty state, DB transaction state etc). You don't need all this data in order to instantiate records when loading serialized value from cache.

## Solution

I don't like to patch ActiveRecord so I have implemented [Compacter](lib/compacter.rb) that takes the value you want to serialize (record, array of records, array of hashes of record or any nested structure you like) and serializes only valuable part of it (skips all the redundant metadata).

## Examples

```ruby
compacter = Compacter.new(Post.last)
Rails.cache.write('posts:last', compacter)
last_post = Rails.cache.read('posts:last')&.data
```

```ruby
class Post < ApplicationRecord
  has_many :comments, dependent: :destroy

  class << self
    # Default caching
    def cached
      Rails.cache.fetch('posts:all') do
        Post.includes(:comments).to_a
      end
    end

    # Caching with compacter
    def cached_compact
      compacter = Rails.cache.fetch('posts:all:cached') do
        Compacter.new(Post.includes(:comments).to_a)
      end

      compacter&.data
    end
  end
end
```

## Testing

I have implemented 2 basic rake tasks to verify how it works:

```
rake compacter:stats                    # Measure dump size
rake compacter:test                     # Tests that compacter does not loose any data
```

## Caveats

- It might work incorrect with different version of Rails (require additional testing);
- It might work incorrect with [serialized attributes](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html#method-i-serialize);
- It relies on ActiveRecord [internals](lib/compacter.rb#L151-L154) (might be a better way);
