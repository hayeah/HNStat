require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "HNStat" do
  let(:tweet_data) {
    json = '
{"coordinates": null,
  "created_at": "Fri Sep 16 03:32:25 +0000 2011",
  "favorited": false,
  "truncated": false,
  "id_str": "114542127005970432",
  "entities": {
    "urls": [{"expanded_url": "http://vimeo.com/28413747",
               "url": "http://t.co/Al4GWKQd",
               "indices": [42, 62],
               "display_url": "vimeo.com/28413747"
             }],
    "hashtags": [],
    "user_mentions": []
  },
  "in_reply_to_user_id_str": null,
  "text": "Intercontinental Ballistic Microfinance:  http://t.co/Al4GWKQd",
  "contributors": null,
  "id": 114542127005970432,
  "in_reply_to_status_id_str": null,
  "retweet_count": 0,
  "geo": null,
  "retweeted": false,
  "in_reply_to_user_id": null,
  "possibly_sensitive": false,
  "place": null,
  "source": "<a href=\"http://twitterfeed.com\" rel=\"nofollow\">twitterfeed</a>",
  "in_reply_to_screen_name": null,
  "user": {"id_str": "213117318", "id": 213117318},
  "in_reply_to_status_id": null}
'
    MultiJson.decode(json.strip)
  }

  describe HNStat::Tweet do
    let(:tweet) { HNStat::Tweet.new(tweet_data) }

    it "parses urls" do
      tweet.urls.should == ["http://vimeo.com/28413747"]
    end

    it "parses creation timestamp" do
      tweet.created_at.should be_a(Time)
    end
  end
end
