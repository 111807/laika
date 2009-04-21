#
# This deploy script is designed to deploy Laika to a configured Amazon EC2
# instance.
#
# To deploy Laika, go to the parent directory and type 'cap deploy'
#

#
# You must specify scm_username, scm_password and server_name in deploy_local.rb.
#
load File.dirname(__FILE__) + '/deploy_local.rb'

#
# In order to automatically authenticate via SSH you must add the correct
# PEM key to your ssh-agent:
#
#  $ ssh-add $YOUR_AMAZON_SSH_PEM_KEY
#
set :ssh_options, { :forward_agent => true }

# glassfish config, see lib/recipes/glassfish.rb
set :context_root, "/"
set :glassfish_location, "/usr/local/glassfish"

# FIXME For now, we are deploying to EC2 as the root user.
set :user, 'root'
set :user_sudo, false

# git config
set :scm,         'git'
set :deploy_via,  :remote_cache
set :branch,      'master'

# application-specific configuration
set :application, 'laika'
set :repository,  'http://github.com/CCHIT/laika.git'
set :deploy_to,   '/vol/laika'
set :rails_env,   'production'
set :rake,        '/usr/local/jruby/bin/jruby -S rake'

role :app, server_name
role :web, server_name
role :db,  server_name, :primary => true

# these tasks are all automatic and shouldn't need to be called explicitly
namespace :laika do
  after  "deploy:update_code", "laika:copy_production_configuration"
  after  "deploy:setup", "laika:bootstrap_production_configuration"

  configurations = {
    "database.yml"   => "#{shared_path}/config/database.yml",
  }

  desc "Copy production configuration files stored on the same remote server"
  task :copy_production_configuration, :roles => :app do
    configurations.each_pair do |file, src|
      run "cp #{src} #{release_path}/config/#{file}"
    end
  end

  desc "Copy configuration templates to the shared server config"
  task :bootstrap_production_configuration, :roles => :app do
    run "mkdir -p #{shared_path}/config"
    configurations.each_pair do |file, dest|
      upload "config/#{file}.template", dest, :via => :scp
    end
  end
end

namespace :remote do
  desc "Open a screen on the deploy target server."
  task :screen do
    system "ssh -t #{user}@#{server_name} screen"
  end
end


