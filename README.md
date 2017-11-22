# File-based Content Management System
___
A file-based content management system that allows users to add, edit, delete, duplicate documents. Users can also upload images to the system as links.

This application can read and parse Markdown and plain-text files. Images uploaded will be embedded as links in Markdown files. Users are able to view previous edit history of a given document.

## Installation
To install dependencies:

```
bundle install
```

To run application:

```
bundle exec ruby cms.rb
```

Then, open up a web browser and request `localhost:4567` in the URL address bar.

## Images

To upload an image:
- Click 'Upload Image' at the bottom of the index page 
- Copy and paste OR drag and drop an image URL into the form
- Hit 'Upload' button
- Your image will be created as a new `.md` document with the image embedded as a link
- When it is viewed, the application will automatically retrieve the full image and display it in your browser

## Edit History
To enable and view history:
- Click on 'Edit' button on a document that you wish to edit
- Edit the document in the text box
- Click 'Save Changes' once completed
- Click 'Edit' button on the edited document
- You should see the version history at the bottom of the page. Click on the timestamp to view previous versions


## Tests
To run tests:

```
bundle exec rake test
```

The test uses `Rack::Test::Methods` to simulate a logged-in session.

#### Heroku Incompatibility

Since this application is file-based, it is not compatible with Heroku. Any files created or any changes made to the files by the application will be discarded each time it goes to sleep.
