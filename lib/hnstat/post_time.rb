class HNStat::PostTime
  include Let
  
  class << self
    def data
      bins = {"hour" => {}, "wday" => {}}
      tweets.find().each do |data|
        t = Time.at(data["created_at"]).utc
        %w(hour wday).each do |f|
          i = t.send(f)
          bins[f] ||= Hash.new
          bins[f][i] ||= 0
          bins[f][i] += 1
        end
      end
      bins
    end
    
    def process(opts={})
      to_process(opts).each do |data|
        self.new(data).process
      end
    end
    
    def to_process(opts={})
      self.tweets.find({"post_time" => {"$exists" => false}},{})
    end
    
    def tweets
      HNStat.tweets
    end
  end

  attr_reader :tweet
  def initialize(data)
    @tweet = HNStat::Tweet.new(data)
  end

  let(:post_time) {
    t = tweet.created_at
    %w(year month day wday hour).inject({}) {|h,unit|
      h[unit] = t.send(unit)
      h
    }
  }

  def process
    tweet.set("post_time",post_time)
  end
end
