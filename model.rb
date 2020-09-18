require 'dm-core'
require 'dm-migrations'
require 'net/http'
require 'uri'

class User
  include DataMapper::Resource
  property :id, Serial
  property :user_id, Decimal, :precision => 32, :required => true
  property :nickname, String, :length => 256, :required => true
  has 1, :ifttt, 'IFTTT'
  has n, :deliveries
end

class IFTTT
  include DataMapper::Resource
  property :id, Serial
  property :access_key, String, :length => 128, :required => true
  property :event_name, String, :length => 256, :required => true
  belongs_to :user

  def url
    "https://maker.ifttt.com/trigger/#{access_key}/with/key/#{event_name}"
  end

  def punch
    uri = URI.parse(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    res = https.request(req)
  end
end

class Delivery
  include DataMapper::Resource
  property :id, Serial
  property :tracking_number, String, :length => 128, :required => true
  belongs_to :user
end

DataMapper.finalize

def database_upgrade!
  User.auto_upgrade!
  IFTTT.auto_upgrade!
  Delivery.auto_upgrade!
end
