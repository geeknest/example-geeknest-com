    # RVM bootstrap
    $:.unshift(File.expand_path('./lib', ENV['rvm_path']))
    require "rvm/capistrano"
    set :rvm_ruby_string, '1.9.2@example-geeknest-com'
    set :rvm_type, :user

    # bundler bootstrap
    require 'bundler/capistrano'

    set :application, "example.geeknest.caseywest.com"
    set :repository,  "http://github.com/geeknest/example-geeknest-com"

    ssh_options[:forward_agent] = true
    default_run_options[:pty] = true
    set :deploy_to, "/home/deploy/sites/example.geeknest.com"
    set :deploy_via, :remote_cache
    set :repository, "git@github.com:geeknest/example-geeknest-com.git"
    set :scm, :git
    set :user, :deploy
    set :use_sudo, false

    role :web, "example.geeknest.caseywest.com"                          # Your HTTP server, Apache/etc
    role :app, "example.geeknest.caseywest.com"                          # This may be the same as your `Web` server
    role :db,  "example.geeknest.caseywest.com", :primary => true # This is where Rails migrations will run

    namespace :deploy do
      task :start do ; end
      task :stop do ; end
      task :restart, :roles => :app, :except => { :no_release => true } do
        run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
      end

      namespace :db do
        desc "Create Production Database"
        task :create do
          puts "\n\n=== Creating the Production Database! ===\n\n"
          run "cd #{current_path}; rake db:create RAILS_ENV=production"
        end
      end
    end

    namespace :bundler do
      task :create_symlink, :roles => :app do
        shared_dir = File.join(shared_path, 'bundle')
        release_dir = File.join(current_release, '.bundle')
        run("mkdir -p #{shared_dir} && ln -s #{shared_dir} #{release_dir}")
      end
  
      task :bundle_new_release, :roles => :app do
        bundler.create_symlink
        run "cd #{release_path} && bundle install --without test"
      end
  
      task :lock, :roles => :app do
        run "cd #{current_release} && bundle lock;"
      end
  
      task :unlock, :roles => :app do
        run "cd #{current_release} && bundle unlock;"
      end
    end

    # HOOKS
    after "deploy:update_code" do
      bundler.bundle_new_release
      # ...
    end

