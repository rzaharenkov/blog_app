class Post < ApplicationRecord
  has_many :comments, dependent: :destroy

  class << self
    def cached
      Rails.cache.fetch('posts:all') do
        Post.includes(:comments).to_a
      end
    end

    def cached_compact
      compacter = Rails.cache.fetch('posts:all:cached') do
        Compacter.new(Post.includes(:comments).to_a)
      end

      compacter&.data
    end

    def comments_stats
      compacter = Rails.cache.fetch('posts:comments_stats') do
        data = Post.includes(:comments).each_with_object([]) do |post, memo|
          memo << {
            post: post,
            comments_count: post.comments.size
          }
        end

        Compacter.new(data)
      end

      compacter&.data
    end
  end
end
