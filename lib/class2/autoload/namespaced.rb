require "class2"

unless caller.find { |bt| bt =~ /(.+):\d+:in\s+`require'\z/ }
  abort "class2: cannot auto detect namespace: cannot find what required me"
end

source = $1
namespace = source =~ %r{/lib/(.+?)(?:\.rb)?\z} ? $1 : File.basename(source, File.extname(source))
Class2.autoload(namespace.camelize, caller.unshift(caller[0]))
