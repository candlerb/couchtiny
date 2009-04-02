require 'couchtiny/utils'
require 'couchtiny/uuids'

module CouchTiny

# This class represents a CouchDB server, and has methods for accessing
# the server state and listing databases. Call the database() method
# to interact with a particular Database.

class Server
  attr_accessor :url, :http, :uuids
  
  # The following options can be passed:
  #   :http::
  #     The object used for performing HTTP transfers (methods 'get',
  #     'put', 'post', 'delete', 'copy') and JSON serialization
  #   :uuid_batch_size::
  #     The number of uuids to request at one time
  #   :uuids::
  #     A replacement object for allocating uuids
  # Other options are passed to the default CouchTiny::HTTP::RestClient module
  def initialize(url='http://127.0.0.1:5984', opt={})
    @url = url
    @http = opt[:http] || (
      require 'couchtiny/http/restclient'
      HTTP::RestClient.new(opt)
    )
    @uuids = opt[:uuids] || (
      UUIDS.new(self, opt[:uuid_batch_size] || 100)
    )
  end

  # Get an object representing a specific database on this server
  def database(name)
    Database.new(self, name)
  end
  
  # Get another uuid
  def next_uuid
    @uuids.call
  end
    
  # Get the server info
  def info
    @http.get(@url)
  end
  
  # Return array of all databases on the server
  def all_dbs
    @http.get("#{@url}/_all_dbs")
  end
  
  # Return array of active tasks
  def active_tasks
    @http.get("#{@url}/_active_tasks")
  end
  
  # Return server config
  def config
    @http.get("#{@url}/_config")
  end
  
  # Return server stats
  def stats
    @http.get("#{@url}/_stats")
  end
  
  # Start replication. Source and target may be either "/dbname" or
  # a full URL "http://[user:pass@]127.0.0.1:5984/dbname"
  def replicate!(source, target)
    @http.post("#{@url}/_replicate", "source"=>source, "target"=>target)
  end

  # Restart the server
  def restart!
    @http.post("#{@url}/_restart")
  end
end
end
