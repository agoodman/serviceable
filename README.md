# Serviceable

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


## Standard CRUD

    POST /posts.json
    GET /posts.json
    GET /posts/1.json
    PUT /posts/1.json
    DELETE /posts/1.json

## Query Params

Full listing returned when no query params are given

    GET /posts.json
    [{"id":1,"title":"First Post!","body":"Feels good to be first","created_at":"20130727T16:26:00Z"}]

Use the <code>only</code> param to specify fields on the collection

    GET /posts.json?only=id,title
    [{"id":1,"title","First post!"}]

Use the <code>include</code> param to specify associated objects or collections

    GET /posts.json?include=user
    [{"id":1,"title":"First Post!","body":"Feels good to be first","created_at":"20130727T16:26:00Z","user":{"id":2,"first_name":"Jim","last_name":"Walker","display_name":"Jim W."}}]

Combine params to configure the result contents

    GET /posts.json?only=id,title&include[user][only]=first_name,last_name
    [{"id":1,"title":"First Post!","user":{"first_name":"Jim","last_name":"Walker"}}]

## Filter Params

Use the <code>where</code> param to filter the results

    GET /posts.json?where[posts][published]=true

Use associated objects or collections to filter the set

    GET /posts.json?where[tags][label]=Pinball

## Integrating with jQuery

Working with a serviceable endpoint is easy with jQuery. Here's an example of a request for all posts
tagged as "Pinball" including only post id and title:

    $.ajax({
      url: '/posts.json',
      type: 'GET',
      data: {
        where: {
          tags: {
            label: 'Pinball'
          }
        },
        only: 'id,title'
      },
      success: function(xhr,msg,data) {
        console.log("received "+data.responseJSON.length+" results");
      }
    });
