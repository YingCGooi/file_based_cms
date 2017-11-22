# File-based Content Management System

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

#### Heroku Incompatibility

Since this application is file-based, it is not compatible with Heroku. Any files created or any changes made to the files by the application will be discarded each time it goes to sleep.
