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
      # don't insert if already exists, so we don't override data
      self.tweets.insert(tweet)
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
