require 'couchtiny/utils'

module CouchTiny

# This class represents a CouchDB server, and has methods for accessing
# the server state and listing databases. Call the database() method
# to interact with a particular Database.

class Server
  @options = {}
  class << self
    attr_accessor :options
  end

  attr_accessor :http, :uuid_generator

  CONTENT_TYPE = 'application/json'.freeze
  
  # The following options can be passed:
  #   :url::
  #     The server URL, default http://127.0.0.1:5984
  #   :parser::
  #     The object for JSON serialization (methods 'parse', 'unparse'),
  #     default to the JSON module
  #   :http::
  #     A replacement object for HTTP communication (methods 'get',
  #     'put', 'post', 'delete', 'copy') and JSON serialization
  #   :uuid_batch_size::
  #     The number of uuids to request at one time (default 100)
  #   :uuid_generator::
  #     A replacement object for allocating uuids
  def initialize(opt={})
    opt = self.class.options.merge(opt)
    @http = opt[:http] || (
      require 'couchtiny/http/restclient'
      url = opt[:url] || 'http://127.0.0.1:5984'
      parser = opt[:parser] || (require 'json'; ::JSON)
      HTTP::RestClient.new(url, parser, :headers=>{
        :content_type => CONTENT_TYPE,
        :accept => CONTENT_TYPE,
      })
    )
    @uuid_generator = opt[:uuid_generator] || (
      require 'couchtiny/uuids'
      UUIDS.new(self, opt[:uuid_batch_size] || 100)
    )
  end
  
  # The base URL for this server
  def url
    @http.url
  end
  
  # Get an object representing a specific database on this server
  def database(name)
    Database.new(self, name)
  end
  
  # Get another uuid
  def next_uuid
    @uuid_generator.call
  end
    
  # Get the server info
  def info
    @http.get('/')
  end
  
  # Return array of all databases on the server
  def all_dbs
    @http.get('/_all_dbs')
  end
  
  # Return array of active tasks
  def active_tasks
    @http.get('/_active_tasks')
  end
  
  # Return server config
  def config
    @http.get('/_config')
  end
  
  # Return server stats
  def stats
    @http.get('/_stats')
  end
  
  # Start replication. Source and target may be either "/dbname" or
  # a full URL "http://[user:pass@]127.0.0.1:5984/dbname"
  def replicate!(source, target)
    @http.post('/_replicate', 'source'=>source, 'target'=>target)
  end

  # Restart the server
  def restart!
    @http.post('/_restart')
  end
end
end
