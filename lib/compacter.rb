# Serializes collections of ActiveRecord objects efficently that default Marshal.dump.
#
# It could be useful when you serialize data to memcached (gem dalli uses Marshal.dump to serialize your data).
#
# Usage:
#
#   compacter = Compacter.new(Post.last)
#   Rails.cache.write('posts:last', compacter)
#   last_post = Rails.cache.read('posts:last')&.data
#
# You can also pass in array of records, or hashes, or multidimensional array, or any other nested structures, e.g:
#
#   class Post < ApplicationRecord
#     has_many :comments, dependent: :destroy
#
#     def self.comments_stats
#       compacter = Rails.cache.fetch('posts:comments_stats') do
#         data = Post.includes(:comments).each_with_object([]) do |post, memo|
#           memo << {
#             post: post,
#             comments_count: post.comments.size
#           }
#         end
#
#         Compacter.new(data)
#       end
#
#       compacter&.data
#     end
#   end
#
class Compacter
  ActiveRecordDump = Struct.new(:klass, :attributes, :associations)

  attr_reader :data, :dumped_attributes, :actual_attributes

  def initialize(data)
    @data = data
    @dumped_attributes = {}
    @actual_attributes = {}
  end

  def marshal_dump
    { attributes: dumped_attributes, data: serialize(data) }
  end

  def marshal_load(value)
    @dumped_attributes = value[:attributes]
    @actual_attributes = load_attributes(@dumped_attributes.keys)
    @data = deserialize(value[:data])
  end

  def ==(other)
    other.class == self.class && other.data == data
  end

  private

  def serialize(data)
    case data
    when Hash
      serialize_hash(data)
    when Array
      serialize_array(data)
    when ActiveRecord::Base
      serialize_active_record(data)
    else
      data
    end
  end

  def serialize_hash(hash)
    hash.each_with_object({}) do |(key, value), memo|
      serialized_key = serialize(key)
      serialized_value = serialize(value)
      memo[serialized_key] = serialized_value if serialized_key && serialized_value
    end
  end

  def serialize_array(array)
    array.map { |item| serialize(item) }.compact
  end

  def serialize_active_record(record)
    return nil if record.respond_to?(:do_not_cache?) && record.do_not_cache?

    klass = record.class.name
    attributes = record.attributes

    attributes_names = (dumped_attributes[klass] ||= attributes.keys)

    loaded_associations = record.class.reflections.keys.each_with_object({}) do |reflection_name, memo|
      association = record.association(reflection_name.to_sym)
      if association.loaded? && !inverted?(association)
        memo[reflection_name] = serialize(association.target)
      end
    end

    ActiveRecordDump.new(record.class.name, attributes.values_at(*attributes_names), loaded_associations)
  end

  def deserialize(data)
    case data
    when Hash
      deserialize_hash(data)
    when Array
      deserialize_array(data)
    when ActiveRecordDump
      deserialize_active_record(data)
    else
      data
    end
  end

  def deserialize_hash(hash)
    hash.each_with_object({}) do |(key, value), memo|
      memo[deserialize(key)] = deserialize(value)
    end
  end

  def deserialize_array(array)
    array.map { |item| deserialize(item) }
  end

  def deserialize_active_record(dump)
    klass = dump.klass.constantize
    dumped_attributes_names = dumped_attributes[dump.klass]
    actual_attributes_names = actual_attributes[dump.klass]
    record_attributes = Hash[dumped_attributes_names.zip(dump.attributes)]

    record = klass.instantiate(record_attributes.slice(*actual_attributes_names))

    dump.associations.each do |reflection_name, dumped_records|
      associated_records = deserialize(dumped_records)
      association = record.association(reflection_name.to_sym)
      association.target = associated_records
      Array(associated_records).each do |associated_record|
        association.set_inverse_instance(associated_record)
      end
    end

    record
  end

  def load_attributes(klasses)
    klasses.each_with_object({}) do |klass_name, memo|
      memo[klass_name] = klass_name.constantize.columns_hash.keys
    end
  end

  def inverted?(association)
    # TODO: ActiveRecord doesn't expose this variable anymore. It might be a better way to get this value.
    association.instance_variable_get('@inversed')
  end
end
