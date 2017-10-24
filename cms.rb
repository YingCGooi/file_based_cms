require 'redcarpet'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
require File.join(File.dirname(__FILE__), 'environment')

configure(:development) do
  # require 'pry'
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path('..', __FILE__)

before do
  Dir.chdir(root)
  @files = Dir.chdir('data') { Dir["*"].sort }
  @passwords = YAML.load_file(credentials_path)
end

helpers do
  
end

def data_dir
  return root + 'test/data' if !block_given?

  if ENV["RACK_ENV"] == "test"
    Dir.chdir('test/data') { yield }
  else
    Dir.chdir('data') { yield }
  end
end

def render_markdown(file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(file)  
end

def load_file_content(filename)
  content = data_dir { File.read(filename) }

  case File.extname(filename)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    'test/users.yml'
  else
    'users.yml'
  end  
end

def valid_name(filename)
  !filename.strip.empty? && 
  %w[.txt .md].include?(File.extname(filename))
end

def credentials_match?(username, password)
  return false if !@passwords.has_key?(username)
  BCrypt::Password.new(@passwords[username]) == password.to_s
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
  end
end

def user_signed_in?
  session.key?(:username)
end

# index page
get '/' do
  if !session[:username]
    redirect 'users/signin'
  end

  @username = session[:username]
  erb :index, layout: :layout
end

get '/users/signin' do
  erb :signin, layout: :layout
end

get '/new' do
  require_signed_in_user

  erb :new, layout: :layout
end

get '/:filename' do
  filename = params[:filename]

  if data_dir { !File.file?(filename) }
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end

  load_file_content(filename)
end

get '/:filename/edit' do
  require_signed_in_user

  filename = params[:filename]
  @file = data_dir { File.read(filename) }

  erb :edit, layout: :layout
end

post '/new' do
  require_signed_in_user

  filename = params[:filename].to_s || ""

  if !valid_name(filename)
    session[:message] = "A name with a .txt or .md extension is required."
    status 422
    halt erb :new, layout: :layout
  end

  data_dir { File.write(filename, "") }
  session[:message] = "#{filename} was created."
  redirect '/'
end

post '/users/signin' do
  @username = params[:username]
  @password = params[:password]

  if credentials_match?(@username, @password)
    session[:username] = @username
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin, layout: :layout
  end
end

post '/users/signout' do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect '/'
end

post '/:filename' do
  require_signed_in_user

  filename = params[:filename]

  data_dir { File.write(filename, params[:content]) }

  session[:message] = "#{filename} has been updated!"
  redirect '/'
end

post '/:filename/delete' do
  require_signed_in_user

  filename = params[:filename]
  data_dir { File.delete(filename) }

  session[:message] = "#{filename} was deleted."
  redirect '/'
end

