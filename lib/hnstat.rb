require 'let'
require "multi_json"
require 'rest_client'

module HNStat extend self
  include Let
  let(:db) { HNStat::DB.new }
  def tweets
    db.tweets
  end
end

class HNStat::URLExpander
  require 'url_expander'
  require 'resque'

  include Let
  
  @queue = :url_expand
  
  class << self
    def tweets_to_expand(opts={})
      db.tweets.find({"full_url" => {"$exists" => false}},opts)
    end

    def expand(count=nil)
      tweets_to_expand(:limit => count).each do |data|
        Resque.enqueue(HNStat::URLExpander,data)
      end
    end

    def perform(data)
      self.new(data).expand!
    end

    def db
      @db ||= HNStat::DB.new
    end
  end
  
  attr_reader :tweet
  def initialize(data)
    @tweet = HNStat::Tweet.new(data)
  end

  let(:full_url) {
    UrlExpander::Client.expand(tweet.url, :is_redirection => true)
  }

  def url
    tweet.url
  end
  
  def expand!
    p [:expand,url,full_url]
    db.tweets.update({"_id" => tweet.id},{"$set" => {"full_url" => full_url}})
  end
  
  def db
    HNStat::URLExpander.db
  end
end

class HNStat::Firehose
  # @hnfirehose
  
  API = "http://api.twitter.com/1"
  NAME = "hnfirehose"

  # count: max of 200
  # max_id: Returns results with an ID less than (that is, older than) or equal to the specified ID.
  # since_id:
  def tweets(opts={})
    params = {
      :screen_name => NAME,
      :trim_user => true,
      :include_entities => true
    }.merge(opts)
    get("/statuses/user_timeline.json",params)
  end

  def get(path,params)
    r = RestClient.get "#{API}#{path}", {:params => params, :accept => :json}
    # r.cookies
    # r.headers
    # r code
    MultiJson.decode r.to_str
  end
end

class HNStat::DB
  require 'mongo'
  require 'bson'

  def self.default_mongo
    Mongo::Connection.new("localhost").db("hnstat")
  end

  attr_reader :mongo, :hose, :tweets
  def initialize(mongo=HNStat::DB.default_mongo)
    @mongo = mongo
    @hose = HNStat::Firehose.new
  end

  def tweets
    # create with unique index
    return @tweets if @tweets
    @tweets = mongo.collection("tweets")
    @tweets.ensure_index([["_id",Mongo::DESCENDING]],:unique => true)
    @tweets
  end

  def oldest_known_id
    o = oldest
    return nil unless o
    o["_id"]
  end

  def newest_known_id
    o = newest
    return nil unless o
    o["_id"]
  end

  def begin_time
    o = newest
    o && Time.at(o["created_at"])
  end

  def end_time
    o = oldest
    o && Time.at(o["created_at"]) 
  end
  
  def time_range
    [begin_time,end_time]
  end
  
  def newest
    tweets.find_one({},:sort => [["_id",Mongo::DESCENDING]])
  end

  def oldest
    tweets.find_one({},:sort => [["_id",Mongo::ASCENDING]])
  end

  # load multiples of 200 from head until it catches up with what there is in the database.
  def update!(oldest_result = nil)
    # load until there's nothing to load, or we've already reached the end.
    puts "load until #{newest_known_id}"
    loop do
      if oldest_result
        params = {:count => 200, :max_id => oldest_result["id"]-1}
      else
        params = {:count => 200}
      end
      
      results = hose.tweets(params)
      break if results.empty? # stop when no tweets are found

      pp [:saving,results.first["id"],results.last["id"]]
      oldest_result = results.last
      overlapped = true if self.tweets.find_one({"_id" => oldest_result["id"]})
      store_tweets results # the tail is already in the db, but there may be other tweets we haven't stored yet
      puts "count: #{self.count}..."
      break if overlapped # stop when the end of this batch of tweet is already in database
    end
    puts "now at #{newest_known_id}"
  end

  # def load_until(time)
  #   goal = time
  #   cursor = end_time || Time.now
  #   loop do
  #     break if cursor < goal
  #     load_older
  #     cursor = end_time
  #     puts "at: #{end_time}"
  #     puts "count: #{self.count}"
  #     puts
  #   end
  # end
  
  # check to see if there is anything new
  def load_newer(count=200)
    
    params = {:count => count}
    if since_id = newest_known_id
      params[:since_id] = since_id
    end
    store_tweets hose.tweets(params)
  end

  # load from the back
  def load_older(count=200)
    if max_id = oldest_known_id
      store_tweets hose.tweets({:count => count, :max_id => max_id-1})
    else # never was loaded before. So we just load from beginning
      load_newer
    end
  end

  def store_tweets(tweets)
    # transform date to integer
    # put link on top
    # map id to _id
    tweets = tweets.map { |tweet|
      tweet["_id"] = tweet["id"]
      tweet["created_at"] = Time.parse(tweet["created_at"]).to_i
      tweet
    }
    return tweets if tweets.empty?
    tweets.each do |tweet|
      self.tweets.save(tweet)
    end
    tweets
  end

  def reset!
    tweets.remove
  end

  def count
    tweets.count
  end
end

# how should I treat repeated submission?
# what questions do I want to ask?
## it would be interesting to find the correlation of votes between for the same url
class HNStat::HackerNews
  API = "http://api.ihackernews.com/"

  attr_reader :tweet
  def initialize(tweet)
    @tweet = tweet
  end

  # list of possible ids
  def ids 
    get("/getid",:url => tweet.url)
  end

  # select a matching id
  def id 
  end

  def data
    # Retrieve Post (includes url, title, comments, etc...)
    # http://api.ihackernews.com/post/{id}
    get("/post/#{self.id}")
  end

  def get(path,params)
    r = RestClient.get "#{API}#{path}", {:params => params, :accept => :json}
    # r.cookies
    # r.headers
    # r code
    MultiJson.decode r.to_str
  end
end

class HNStat::Tweet
  include Let

  attr_reader :data, :hn

  def initialize(data)
    @data = data
    # @hn = HNStat::API.new
  end

  def text
    data["text"]
  end

  def id
    data["_id"]
  end

  let(:url) { urls.first }
  
  let(:urls) {
    data["entities"]["urls"].map { |h| h["expanded_url"] || h["url"] }
  }

  let(:created_at) {
    Time.at data["created_at"]
  }
end



