# config valid for current version and patch releases of Capistrano
lock "~> 3.11.1"

set :application, "uzumeshi"
set :repo_url, "git@github.com:takin6/uzumeshi.git"

set :rails_env, "production"
set :user, "ec2-user"

set :pty, true
# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, 'master'

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/uzumeshi"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml"
set :linked_files, fetch(:linked_files, []).push('config/master.key')

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }
env_vals = {}
File.read("/app/config/.env").split("\n").map do |env|
  key, val = env.split("=")
  env_vals[key] = val
end
set :default_env, env_vals

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

#rbenvをシステムにインストールしたか? or ユーザーローカルにインストールしたか?
set :rbenv_type, :user # :system or :user
# rubyのversion
set :rbenv_ruby, '2.6.3'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
# set :rbenv_map_bins, %w{rake gem bundle ruby rails}
# set :rbenv_roles, :all # default value

set :log_level, :debug

set :sidekiq_role, :app
set :sidekiq_config, "config/sidekiq.yml"
set :sidekiq_env, 'production'
# set :bundle_env_variables, { nokogiri_use_system_libraries: 1 }


namespace :deploy do
  desc 'Restart application'
  task :restart do
    invoke 'unicorn:restart'
  end

  desc 'Create database'
  task :db_create do
    on roles(:db) do |host|
      with rails_env: fetch(:rails_env) do
        within current_path do
          execute :bundle, :exec, :rake, 'db:create'
        end
      end
    end
  end

  desc 'Create elasticsearch index'
  task :elasticsearch_create do
    on roles(:app) do 
      with rails_env: fetch(:rails_env) do
        within current_path do
          execute :bundle, :exec, :rake, 'elasticsearch:create_search_index'
          execute :bundle, :exec, :rake, 'elasticsearch:create_suggest_keyword'
        end
      end
    end
  end

  desc 'recreate mongo_restaurants'
  task :recreate_restaurant_master_data do
    on roles(:app) do 
      with rails_env: fetch(:rails_env) do
        within current_path do
          execute :bundle, :exec, :rake, 'adhoc:restaurant:recreate_master_data'
        end
      end
    end
  end

  desc 'Drop database'
  task :db_drop do
    on roles(:db) do |host|
      with rails_env: fetch(:rails_env) do
        within current_path do
          execute :bundle, :exec, :rake, 'db:drop'
        end
      end
    end
  end

  desc 'Run seed'
  task :db_seed do
    on roles(:app) do
      with rails_env: fetch(:rails_env) do
        within current_path do
     	    execute :bundle, :exec, :rake, 'db:seed'
        end
	    end
    end
  end

  desc 'Run db reset'
  task :db_migrate_reset do
    on roles(:app) do
      with rails_env: fetch(:rails_env) do
        within current_path do
          execute :bundle, :exec, :rake, 'db:migrate:reset'
        end
      end
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
    end
  end
end
