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
