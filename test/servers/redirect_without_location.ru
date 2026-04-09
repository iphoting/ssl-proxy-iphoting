class ProxyTestServer
  def call(env)
    [302, {"content-type" => "image/foo"}, "test"]
  end
end

run ProxyTestServer.new
