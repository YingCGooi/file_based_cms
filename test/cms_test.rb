require_relative 'test_helper'

# Tests for Sinatra app
class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def setup
    Dir.mkdir('test/data') unless Dir.exist?('test/data')
    username_hash = "---\nadmin: "\
      "$2a$10$O6ztkvgjtIR.wFpm71NrVuvPvilNynEaq0G.zmVm/jXB95FBZ.Zi2\n"
    File.write(credentials_file_path, username_hash)
  end

  def teardown
    Dir.chdir('test') { FileUtils.rm_r('data') }
  end

  def create_document(name, content = "")
    data_dir { File.write(name, content) }
  end

  def duplicate_document(name)
    content = Dir.chdir('data') { File.read(name) }
    create_document(name, content)
  end

  def session
    last_request.env["rack.session"]
  end

  def test_index
    create_document "about.txt"
    create_document "changes.txt"
    create_document "history.txt"
    create_document "growing_your_own_web_framework.md"

    get "/", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt" 
    assert_includes last_response.body, "growing_your_own_web_framework.md"
  end

  def test_history_txt
    duplicate_document "history.txt"

    get "/history.txt", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "2015 - Ruby 2.3 released."
    assert_includes last_response.body, "1993 - Yukihiro Matsumoto dreams up Ruby."
  end

  def test_markdown_render
    create_document("growing_your_own_web_framework.md",
      "### What is Rack\n```\nputs 'hello world!'\n```\n")

    get "/growing_your_own_web_framework.md", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "<h3>What is Rack</h3>"
    assert_match(/<code>\s?.+\s?<\/code>/, last_response.body)
  end

  def test_editing_document
    create_document "about.txt"

    get "/about.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "Edit content of 'about.txt':"
    assert_includes last_response.body, "Save Changes"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    create_document "about.txt"

    post "/about.txt", {content: "hello world"}, admin_session
    assert_equal 302, last_response.status

    get "/"
    assert_includes last_response.body, "about.txt has been updated"

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "hello world"

    post "/about.txt", content: ""
  end

  def test_create_new_document
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    %w[<form <input <button submit].each do |text|
      assert_includes last_response.body, text
    end

    post "/new", filename: "Hello World.md"
    assert_equal 302, last_response.status
    assert_includes data_dir { Dir["*"] }, "Hello World.md"
    assert_equal "Hello World.md was created.", session[:message]

    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Hello World.md was created."
  end

  def test_create_new_document_without_filename
    post "/new", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name with a .txt or .md extension is required."
  end

  def test_delete_document
    create_document "example.md"

    post "/example.md/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal [], data_dir { Dir["*"] }
    refute_includes data_dir { Dir["*"] }, "example.md"
    assert_includes session[:message], "example.md was deleted."

    get "/"
    refute_includes last_response.body, %q(href="/example.md")
  end

  def test_load_signin_page
    post '/users/signout'

    get '/users/signin'
    assert_equal 200, last_response.status
    ['Username:', 'Password:', 'input type="password"', 'button type="submit"', 'Sign In'].each do |text|
      assert_includes last_response.body, text
    end
  end

  def test_signin_with_correct_credentials
    post '/users/signout'
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    create_document 'about.txt'

    get '/'
    assert_equal 200, last_response.status

    [ 
      'about.txt</a>',
      'Edit</a>',
      'Delete</button>',
      'New Document',
      'Signed in as admin.',
      'Sign Out</button>'
    ].each do |text| 
      assert_includes last_response.body, text
    end
  end

  def test_signin_with_invalid_credentials
    post '/users/signout'
    post '/users/signin', username: 'hello world', password: 'not a password'
    assert_equal 422, last_response.status

    post '/users/signin', username: 'admin', password: 'not a secret'
    assert_equal 422, last_response.status

    post '/users/signin', username: 'hello', password: 'secret'
    assert_equal 422, last_response.status

    ['Username:', 'Password:', 'input type="password"', 'button type="submit"', 'Sign In', 'hello', 'secret'].each do |text|
      assert_includes last_response.body, text
    end
  end

  def test_signout
    post "/users/signout"
    get "/users/signin"

    assert_nil session[:username]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
  end

  def test_file_not_found
    get '/hello.ext', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "hello.ext does not exist.", session[:message]
  end

  def test_welcome_message
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 'Welcome!', session[:message]
  end

  def test_visit_edit_page_when_signed_out
    create_document 'example.txt'

    get '/example.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_submit_edits_when_signed_out
    create_document 'example.txt'

    post '/example.txt', content: 'some random content'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_view_document_page_when_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_submit_new_document_page_when_signed_out
    post '/new', filename: 'new_file.txt'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]  
  end

  def test_delete_document_when_signed_out
    create_document 'example.txt'

    post '/example.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]      
  end

  def test_duplicate_file
    create_document 'hello.txt'

    post '/hello.txt/copy', {}, admin_session
    assert_equal 302, last_response.status
    assert_includes(data_dir { Dir['*'] }, 'hello(2).txt')

    post '/hello.txt/copy', {}, admin_session
    assert_includes(data_dir { Dir['*'] }, 'hello(3).txt')

    post '/hello(2).txt/delete', {}, admin_session
    refute_includes(data_dir { Dir['*'] }, 'hello(2).txt')

    post '/hello.txt/copy', {}, admin_session
    assert_includes(data_dir { Dir['*'] }, 'hello(2).txt')

    create_document 'copy_this.md', '## Copy This!'

    24.times { post '/copy_this.md/copy' }
    assert_includes(data_dir { Dir['*'] }, 'copy_this(25).md')
    assert_includes(data_dir { File.read('copy_this(24).md')}, '## Copy This!' )
  end

  def test_signup
    get '/users/signup'
    assert_equal 200, last_response.status
    assert_match(/Username:\s*<input type="text"/, last_response.body)
    assert_match(/Password:\s*<input type="password"/, last_response.body)

    post '/users/signup', username: 'hello', password: '123'
    assert_equal 302, last_response.status
    assert_match(/hello.+has been created/, session[:message])

    post '/users/signin', username: 'hello', password: '123'
    assert_equal 302, last_response.status
    assert_match(/Welcome/, session[:message])

    get '/'
    assert_equal 200, last_response.status
    assert_match(/signed in as hello/i, last_response.body)
  end

  def test_upload_image
    get '/upload', {}, admin_session
    assert_equal 200, last_response.status
    assert_match(/Upload an image to CMS/, last_response.body)
    assert_match(/<input.+type="text"/, last_response.body)
    assert_match(/<button.+type="submit"/, last_response.body)

    url = 'http://images5.fanpop.com/image/photos/28100000/'\
      'Cute-kitty-animal-cubs-28185372-1920-1200.jpg'
    post '/upload/image', upload: url
    assert_equal 302, last_response.status
    assert_match(/image.{0,100} has been successfully uploaded/i, session[:message])

    filename = 'Cutekittyanimalcubs2818537219201200.md'
    get '/' + filename
    assert_equal 200, last_response.status
    assert_match(/<img src=".+1200\.jpg"/, last_response.body)

    url = 'http://www.fanpop.com/clubs/animal-cubs/'\
    'images/28185372/title/cute-kitty-wallpaper'
    post '/upload/image', upload: url
    assert_equal 415, last_response.status
    assert_match(/Invalid image url/, last_response.body)
  end

  def test_preserve_versions
    create_document 'changes.txt', 'first version'

    post '/changes.txt', { content: 'second version' }, admin_session
    creation_time = Time.now.to_s
    assert_equal 302, last_response.status

    data_dir do
      Dir["changes/*"].each do |filename|
        assert_includes filename, creation_time
      end
    end

    get '/changes.txt'
    assert_includes 'second version', last_response.body

    v1_content = data_dir { File.read("changes/#{creation_time}.txt") }
    assert_includes v1_content, 'first version'

    post '/changes.txt', { content: 'Third version!' }
    creation_time = Time.now.to_s
    assert_equal 302, last_response.status

    post '/changes.txt', { content: ' ' }

    get "/changes/#{creation_time.gsub(' ','%20')}.txt/view"
    assert_includes 'Third version!', last_response.body
  end
end
