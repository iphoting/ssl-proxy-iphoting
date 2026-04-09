run lambda { |env|
  path = File.expand_path('../octocat.jpg', __FILE__)
  data = File.read(path)
  [404, {'content-type' => 'image/jpeg'}, [data]]
}
