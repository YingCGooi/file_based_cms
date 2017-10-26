require 'redcarpet'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
require 'pry'
require File.join(File.dirname(__FILE__), 'environment')

configure(:development) do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

ROOT = File.expand_path('..', __FILE__)

before do
  Dir.chdir(ROOT)
  @files = data_dir { Dir["*"].sort }
  @passwords = YAML.load_file(credentials_file_path)
end

helpers do
  def home_page?
    %w[/ /users/signin].include? env['REQUEST_PATH']
  end

  def h(content)
    Rack::Utils.escape_html(content)
  end
end

def p5(str); 5.times { p str }; end

def data_dir
  if ENV["RACK_ENV"] == "test"
    return ROOT + '/test/data' if !block_given?
    Dir.chdir('test/data') { yield }
  else
    return ROOT + '/data' if !block_given?
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

def credentials_file_path
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
  return false if !@passwords.key?(username)
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

def basename(filename, extension)
  filename[/.+(?=\(\d+\)#{extension}$)/] || File.basename(filename, extension)
end

def next_filenumber(filename)
  extension = File.extname(filename)
  basename = basename(filename, extension)

  next_number = find_next_number(basename, extension)
  basename + "(#{next_number})" + extension
end

def find_next_number(basename, ext)
  existing_numbers =
    data_dir do
      Dir[basename + '*' + ext].map do |filename|
        filename[/(?<=\()\d+(?=\)#{ext}$)/].to_i
      end.compact
    end

  (2..existing_numbers.max + 1).find do |num|
    !existing_numbers.include?(num)
  end || 2
end

def valid_img_url(url)
  url.length < 256 && url[/^https?:\/\//] && %[.jpg jpeg .png .gif .bmp tiff ashx].include?(url[-4..-1])
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

get '/upload' do
  require_signed_in_user

  erb :upload, layout: :layout
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

post '/:filename/copy' do
  require_signed_in_user

  filename = params[:filename]

  next_filename = next_filenumber(filename)
  data_dir { FileUtils.cp(filename, next_filename) }

  redirect '/'
end

get '/users/signup' do
  erb :signup, layout: :layout
end

post '/users/signup' do
  @username = params[:username]
  @password = params[:password]

  session[:message] =
    if @username.strip.empty? || @username.include?(' ')
      "Please enter a valid username. " \
      "Usernames must not contain spaces or empty."
    elsif @passwords.key?(@username)
      "Username is already in use."
    elsif @password.strip.empty?
      "Please enter a valid password."
    end

  halt erb :signup, layout: :layout if session[:message]

  hashed = BCrypt::Password.create(@password)
  new_data_row = "#{@username}: #{hashed}\n"
  File.write(credentials_file_path, new_data_row, mode: 'a')

  session[:message] = "The user '#{@username}' has been created!"
  redirect '/'
end

post '/upload/image' do
  require_signed_in_user
  
  img_url = params[:upload]

  if !valid_img_url(img_url)
    session[:message] = 'Invalid image url. Please try again.'
    halt erb :upload, layout: :layout
  end

  img_filename = img_url.split('/')
                        .last[/.+(?=\..{2,4})/]
                        .gsub(/\W/, '')
                        .concat('.md')
                      
  img_str = "![#{img_filename}](#{img_url})"
  data_dir { File.write(img_filename, img_str) }

  session[:message] = "Image #{img_filename} has been successfully uploaded!"
  redirect '/'
end