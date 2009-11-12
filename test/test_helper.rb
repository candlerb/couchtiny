require 'test/unit'
require File.dirname(__FILE__)+'/contest'
$:.unshift File.expand_path(File.dirname(__FILE__)+'/../lib')

SERVER_URL = 'http://127.0.0.1:5984'
DATABASE_NAME = 'couchtiny-test'
DATABASE2_NAME = 'couchtiny-test2'

require 'restclient'
TEST_HTTP_NOT_FOUND = RestClient::ResourceNotFound

# Ugh, active_support 2.3.4 breaks JSON.unparse, load if it's available
begin
  require 'active_support'
rescue LoadError
  warn "Testing without active_support"
end
