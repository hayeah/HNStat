$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'let'
require "multi_json"
require 'rest_client'

module HNStat extend self
  include Let
  let(:db) { HNStat::DB.new }
  def tweets
    db.tweets
  end

  def update!
    db.update!
    HNStat::URLExpander.expand
  end
end

require 'hnstat/url_expander'
require 'hnstat/firehose'
require 'hnstat/db'
require 'hnstat/api'
require 'hnstat/tweet'








