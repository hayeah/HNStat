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
