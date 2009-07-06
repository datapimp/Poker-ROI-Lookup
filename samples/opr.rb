require 'rubygems'
require 'mechanize'
require 'logger'
require File.dirname(__FILE__) + '/../lib/roi_lookup'

opr_username = "jonathan.soeder@gmail.com"
opr_password = "xxxxxx"

lookup_config = {
  :login => opr_username,
  :password => opr_password,
  :roi_source => "opr"
}

@lookup = RoiLookup.new lookup_config

#@lookup.run ['ThePapaya']
#puts @lookup.results.get('ThePapaya')[:roi_percent]

@hh = HandHistory.new 'T175253352'

@hh.last.players.each do |player|
  @lookup.run(player)
  puts @lookup.results.get(player).inspect
end
