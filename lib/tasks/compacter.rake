namespace :compacter do
  desc 'Measure dump size'
  task :stats => :environment do |t, args|
    posts = Post.includes(:comments).to_a

    puts "Serialazing #{posts.size} posts ..."

    default_size = Marshal.dump(posts).size
    compact_size = Marshal.dump(Compacter.new(posts)).size
    ratio = (default_size.to_f / compact_size).round(4)

    puts "Default serialization: #{default_size} bytes"
    puts "Compact serialization: #{compact_size} bytes (#{ratio} times less than default)"
  end

  desc 'Tests that compacter does not loose any data'
  task :test => :environment do |t, args|
    posts = Post.includes(:comments).to_a

    deserialized_posts = Marshal.load(Marshal.dump(posts))
    deserialized_compact_size = Marshal.load(Marshal.dump(Compacter.new(posts))).data

    puts "Deserialized posts are equals: #{deserialized_posts == deserialized_compact_size}"
  end
end
