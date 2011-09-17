# how should I treat repeated submission?
# what questions do I want to ask?
## it would be interesting to find the correlation of votes between for the same url
class HNStat::API
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
