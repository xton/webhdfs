#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), 'webhdfs', 'backport.rb')
require File.join(File.dirname(__FILE__), 'webhdfs', 'client.rb')

if $0 == __FILE__
  require 'pp'
  require 'yaml'

  config = YAML.load_file(File.expand_path("~/.webhdfs_debug_config.yml"))

  client = WebHDFS::Client.new(config['test_host'], config['test_port'], config['test_user'], config['test_user'] )
  client.httpfs_mode = true

  verb, path, *args = ARGV
  cmds = []
  opt = {}
  args.each do |arg|
    if arg['=']
      k,v = arg.split("=")
      opt[k] = v
    else
      cmds << arg
    end
  end

  verb_aliases = {
    'ls' => 'list',
    'mv' => 'rename',
    'rm' => 'delete',
    'cat' => 'read',
  }

  verb = verb_aliases[verb] || verb

  path ||= '.'
  path = "/user/#{config['test_user']}/" + path unless path =~ %r[^/]

  # $stderr.puts "WILL: #{verb} #{path} #{cmds.inspect} #{opt.inspect}"

  if verb == 'resolve_glob'
    client.resolve_glob(path, *args, opt) do |path|
      puts path
    end
    exit
  end

  client.resolve_glob(path) do |final_path|
    out = client.send(verb, final_path, *args, opt)

    if verb == 'list'
      out.each do |r|
        puts "#{r['pathSuffix']}#{r['type'] == 'DIRECTORY' ? '/' : ''}"
      end
    elsif verb == 'read'
      print out
    else
      pp out
    end
  end

end