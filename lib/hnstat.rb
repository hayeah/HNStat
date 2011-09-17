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

["url_expander","firehose","db","api","post_time","tweet"].each do |m|
  if debug = false
    load "hnstat/#{m}.rb"
  else
    require "hnstat/#{m}"
  end
end
