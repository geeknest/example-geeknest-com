# Multi-tenant Rails 3 Server (Ubuntu, Postfix, MySQL, RVM, Phusion Passenger, Nginx, Ruby 1.9.2, and github)

Here's how I setup an Ubuntu 11.04 server to host multiple light-weight and starter rails projects. This setups gives you an easy way to deploy projects quickly. One less excuse to get that next project on the Internet for people to use.

## System Setup and Software

From a fresh install you ought to begin by updating your system installed software.

    server$ apt-get update && apt-get upgrade && apt-get dist-upgrade && reboot

## Install Dependencies

### RVM dependencies

    server$ sudo apt-get install ruby ruby1.8 ruby-dev libruby1.8 zlib1g-dev libssl-dev libreadline5-dev libncurses5-dev build-essential curl git-core libxml2 libxml2-dev libxslt1-dev bison autoconf

### ruby dependencies

    server$ sudo apt-get install build-essential bison openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake

### nginx dependencies

    server$ sudo apt-get install libcurl4-openssl-dev

## Install postfix

    server$ sudo apt-get install postfix

You'll be asked several questions when installing postfix. Here are the answers:

- Internet Site
- Your `default.com` site

Configure any email aliases you like by adding them to `/etc/aliases` and running this command.

    server$ sudo newaliases

## Install mysql

    sudo apt-get install mysql-server mysql-client libmysqlclient-dev

You'll be asked to fill in the MySQL root user password. Decide how you like.

## Setup Your Deployment User

Create a new user that will manage and run your applications.

    server$ sudo adduser deploy
    server$ sudo adduser deploy sudo

You'll supply a password for the `deploy` user, but use it just once to install your ssh key. On your development machine you should already have an ssh key. If you don't know, stop and follow <a href="http://help.github.com/mac-set-up-git/">github's guide to setting up git</a>.

Now you can use SSH to upload your key to the new `deploy` user's `authorized_keys`.

    dev$ cat ~/.ssh/id_[dr]sa.pub  | ssh deploy@rails-launcher.caseywest.com "mkdir -p .ssh && cat >> .ssh/authorized_keys && chmod 700 .ssh && chmod 600 .ssh/authorized_keys"

## Install RVM

    server$ bash < <(curl -s https://rvm.beginrescueend.com/install/rvm)
    server$ source ~/.bashrc
    server$ echo 'export rvm_trust_rvmrcs_flag=1' >> $HOME/.rvmrc && rvm reload
    server$ echo 'export rvm_project_rvmrc=1' >> $HOME/.rvmrc && rvm reload
    server$ mkdir /home/deploy/sites

## Install ruby 1.9.2 with RVM

    server$ rvm install 1.9.2
    server$ rvm --default 1.9.2

## Install passenger and nginx

    server$ gem install passenger
    server$ rvmsudo passenger-install-nginx-module

Select option 1 for simplicity.

    server$ sudo vim /etc/init/nginx

Here is the contents of that file:

    description "Nginx HTTP Server"

  	start on filesystem
  	stop on runlevel [!2345]

  	respawn

  	exec /opt/nginx/sbin/nginx -g "daemon off;"

Change the user for nginx to `deploy`.

    server$ sudo vim /opt/nginx/conf/nginx.conf

Add this line:

    user deploy;

## Creating your Virtual Host Setup

Edit your `nginx.conf` and add an include in your `http` section.

    server$ sudo vim /opt/nginx/conf/nginx.conf

Add this line:

    http {
      # ...
      
      include /home/deploy/sites/*/current/config/nginx.conf;
    }

## Setup Your Application

    $dev rvm use --create 1.9.2@example-geeknest-com
    $dev gem install rails --pre
    $dev rails new example-geeknest-com -d mysql
    $dev cd example-geeknest-com
    $dev rvm use 1.9.2@example-geeknest-com --rvmrc --create

Uncomment the use of the `capistrano` gem in your `Gemfile`:

    gem 'capistrano'

Also, to deploy a Rails 3.1 application you must have a JavaScript Runtime for CoffeeScript. I recommend `therubyracer`, which you can also add to your `Gemfile`:

    gem 'therubyracer'

Run bundler.

    dev$ bundle

In your Rails project create a new file, `config/nginx.conf` with the following contents:

    server {
      listen 80;
      server_name example.geeknest.com example.geeknest.caseywest.com;
      root /home/deploy/sites/example.geeknest.com/current/public;
      passenger_enabled on;
    }


In your Rails project create a new file, `config/setup_load_paths.rb` with the following contents:

    if ENV['MY_RUBY_HOME'] && ENV['MY_RUBY_HOME'].include?('rvm')
      begin
        rvm_path     = File.dirname(File.dirname(ENV['MY_RUBY_HOME']))
        rvm_lib_path = File.join(rvm_path, 'lib')
        $LOAD_PATH.unshift rvm_lib_path
        require 'rvm'
        RVM.use_from_path! File.dirname(File.dirname(__FILE__))
      rescue LoadError
        # RVM is unavailable at this point.
        raise "RVM ruby lib is currently unavailable."
      end
    end

    # Select the correct item for which you use below.
    # If you're not using bundler, remove it completely.

    # If we're using a Bundler 1.0 beta
    ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', File.dirname(__FILE__))
    require 'bundler/setup'

    # Or Bundler 0.9...
    if File.exist?(".bundle/environment.rb")
      require '.bundle/environment'
    else
      require 'rubygems'
      require 'bundler'
      Bundler.setup
    end

Setup capistrano. First run `capify`.

    def$ capify .

Replace the contents of `config/deploy.rb` with the following:

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

Adjust your `mysql.sock` expected location in `config/database.yml`:

    production:
      adapter: mysql2
      ...
      socket: /var/run/mysqld/mysqld.sock

Push your repository to github. You may first need to create the repository on github using XXXthese instructionsXXX.

    dev$ git push origin master

First, create the gemset for your application on the server if you haven't already.

    server$ rvm use --create 1.9.2@example-geeknest-com
    server$ gem install bundler

Now deploy via Capistrano:

    dev$ cap deploy:setup
    dev$ cap deploy
    dev$ cap deploy:db:create

Start nginx on the server.

    server$ sudo service nginx start

Open your website and see.