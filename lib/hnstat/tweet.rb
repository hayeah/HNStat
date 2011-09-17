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

  def set(field,value)
    tweets.update({"_id" => id},{"$set" => {field => value}})
  end
  
  def tweets
    HNStat.tweets
  end
end
