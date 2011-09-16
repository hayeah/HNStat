require 'let'
require "multi_json"
class HNStat
  
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



