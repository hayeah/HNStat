require 'let'
require "multi_json"
require 'rest_client'

class HNStat
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
    tweets.find_one({})
  end

  def oldest
    tweets.find_one({},:sort => [["_id",Mongo::ASCENDING]])
  end

  # load multiples of 200
  def load(count)
    ((count / 200) + 1).times do
      self.load_older
    end
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
    self.tweets.insert(tweets)
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
class HNStat::API
  "http://api.ihackernews.com/"

  # Find submitted articles by URL
  # http://api.ihackernews.com/getid?url={url}

  # Retrieve Post (includes url, title, comments, etc...)
  # http://api.ihackernews.com/post/{id}
end

class HNStat::Tweet
  include Let
  attr_reader :data

  def initialize(data)
    @data = data
  end

  let(:urls) {
    data["entities"]["urls"].map { |h| h["expanded_url"] }
  }

  let(:created_at) {
    Time.parse data["created_at"]
  }
end



