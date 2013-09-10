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
    client.resolve_glob(path, *args, opt) do |sub_path|
      puts sub_path
    end
    exit
  end

  # give glob, returns all paths which match.
  def client.resolve_glob path, opt = {}, &p
    components = path.split(File::SEPARATOR).map {|x| x=="" ? File::SEPARATOR : x}

    first_glob_index = components.index do |comp|
      comp =~ /(?<!\\)[\{\}\[\]\*\?]/
    end

    if first_glob_index
      pre_filter = components[0...first_glob_index]
      filter_string = components[first_glob_index]
      post_filter = components[(first_glob_index+1) .. -1]
      begin
        out = list File.join(pre_filter), 'filter' => filter_string
        out.flat_map do |f|
          resolve_glob File.join(*pre_filter,f['pathSuffix'],*post_filter), :leaf_glob => post_filter.empty?, &p
        end
      rescue WebHDFS::FileNotFoundError => e
        []
      end
    elsif opt[:leaf_glob]
      # this came directly from a list
      block_given? and yield path
      [path]
    else
      begin
        out = list(path)
        out.empty? and raise WebHDFS::FileNotFoundError
        block_given? and yield path
        [path]
      rescue WebHDFS::FileNotFoundError, WebHDFS::ServerError => e
        []
      end
    end
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