# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

def regenerate_posts
  Post.destroy_all
  create_posts
end

def create_posts(count: 10)
  count.times do
    post = Post.create!(title: Faker::Lorem.sentence, body: Faker::Lorem.paragraph(3))
    create_comments(post)
  end
end

def create_comments(post, count: 10)
  count.times do
    post.comments.create!(body: Faker::Lorem.paragraph)
  end
end

regenerate_posts
