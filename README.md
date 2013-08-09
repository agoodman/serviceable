Serviceable
=========

Serviceable aims to reduce code duplication for common patterns, such as JSON/XML
API endpoints. Instead of repeating the same patterns in multiple controllers and
trying to maintain that over time, we extracted those patterns into a module.

Controller:

    class PostsController < ApplicationController
    
      include Serviceable
      acts_as_service :post
    
    end

Route:

    resources :posts


Standard CRUD
-------------

    POST /posts.json
    GET /posts.json
    GET /posts/1.json
    PUT /posts/1.json
    DELETE /posts/1.json

Query Params
------------

    GET /posts.json
    [{"id":1,"title":"First Post!","body":"Feels good to be first","created_at":"20130727T16:26:00Z"}]

    GET /posts.json?only=id,title
    [{"id":1,"title","First post!"}]
    
    GET /posts.json?include=user
    [{"id":1,"title":"First Post!","body":"Feels good to be first","created_at":"20130727T16:26:00Z","user":{"id":2,"first_name":"Jim","last_name":"Walker","display_name":"Jim W."}}]

Filter Params
-------------

    GET /posts.json?where[tags][label]=Pinball
    returns a set of posts tagged as "Pinball"
