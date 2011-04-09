#!/usr/bin/env ruby
require "yaml"
require "optparse"

rails_env = "development"
optparser = OptionParser.new
optparser.on("-d", "--development"){ rails_env = "development" }
optparser.on("-t", "--test"){ rails_env = "test" }
optparser.on("-p", "--production"){ rails_env = "production" }
optparser.on("--env VAL"){|opt_env| rails_env = opt_env }
optparser.parse!(ARGV)

def is_rails_root?(dir)
  rails_dirs = %w[app config db doc lib public script test vendor]
  found_count = 0
  Dir.foreach(dir) do |fname|
    found_count += 1 if rails_dirs.include?(fname)
  end

  return (found_count == rails_dirs.size)
end

def own_ip
  ifconfig_result = `ifconfig`

  address = ifconfig_result.scan(/inet \d{1,3}(?:\.\d{1,3}){3}/).map{|s| s.sub(/\Ainet /, "") }.select{|adr| adr != "127.0.0.1" }

  return address[0]
end

def quit(msg)
  STDERR.puts(msg)
  exit
end

# determine RAILS_ROOT
pwd = Dir.pwd
while not is_rails_root?(pwd)
  pwd = File.dirname(pwd)
  break if pwd == "/"
end

quit "please execute inside RAILS_ROOT" if pwd == "/"
rails_root = pwd

database_yml_file = File.expand_path("config/database.yml", rails_root)
database_yml_content = File.read(database_yml_file)
yaml = YAML.load(database_yml_content)

db_config = yaml[rails_env]
quit "You specified wrong environment: #{rails_env}, couldn't find config on yaml" if !db_config

adapter = db_config["adapter"]
quit "rails-dbc.rb does not support this adapter type: '#{adapter}'" if adapter !~ /mysql/

this_machine_ip = (db_config["host"] == "localhost") ? "localhost" : own_ip()

# build SQL
create_database_sql = sprintf("CREATE DATABASE `%s`;", db_config["database"])
grant_sql = sprintf("GRANT ALL ON `%s`.* TO '%s'@'%s' IDENTIFIED BY '%s';", db_config["database"], db_config["username"], this_machine_ip, db_config["password"])

# -- finish
puts create_database_sql
puts grant_sql


