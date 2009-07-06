require 'rubygems'
require 'mechanize'
require 'logger'

class RoiLookup
  attr_reader :config
  attr_accessor :roi_source, :login, :password, :results

  def initialize config={}
    @config = config
    @roi_source = config[:roi_source]
    @login = config[:login]
    @password = config[:password]
    @results = RoiLookup::RoiResults.new
  end
  
  def run players=[], poker_site="pokerstars"
    @provider = RoiLookup::RoiProvider.new config
    players.each do |player|
     @results.set( player, @provider.get_roi_for_player(player, poker_site) )
    end
  end
  
  class RoiResults
    attr_accessor :results
    
    def initialize
      @results = {}
    end
    
    def get player
      results[player]
    end
    
    def set player, values
      results[player] = values
    end
  end
  
  class RoiProvider
    attr_accessor :roi_source, :provider_login, :provider_password
    
    def initialize config
      @provider_login = config[:login]
      @provider_password = config[:password]
      @roi_source = config[:roi_source]
    end
    
    def provider
      case roi_source
        when "opr" then RoiLookup::RoiProvider::OPR
        else RoiLookup::RoiProvider::OPR
      end
    end
    
    def get_roi_for_player player, poker_site
      provider.get_roi_for_player player, poker_site, {:login=>provider_login,:password=>provider_password}
    end
    
    class OPR
      def self.get_roi_for_player player, poker_site, auth
        raw_html = get_raw_html(player, poker_site_value(poker_site), auth)
        roi_data = parse_raw_html raw_html
      end
      
      def self.parse_raw_html raw_html
        doc = Nokogiri::HTML( raw_html )
        roi_data = {}
        doc.css('#PlayerContentBackgroundTD table.ContentM table.ContentM').each do |table|
          #we've found the money table
          if table.to_s.match /ITM/
            table.css('tr').each do |row|
              if row.to_s.match /Hold'em NL/
                row_html = row.to_s.gsub!(/onmouseover=".*"/,'').
                                    gsub!(/align=".*"/,'').
                                    gsub!(/style=".*"/,'').
                                    gsub!(/onclick=".*"/,'').
                                    gsub!(/bgcolor=".*"/,'').
                                    gsub!(/\s+/,'').
                                    gsub!(/<tr>|<\/tr>/,'').
                                    gsub!(/<\/td>/,'')
                row_data = row_html.split(/<td>/)

                roi_data = {
                  :prizes => row_data[2],
                  :profit => row_data[3],
                  :roi_percent => row_data[4].gsub!(/\%.*/,''),
                  :average_buyin => row_data[5],
                  :average_fieldsize => row_data[6],
                  :rebuy_addon_percent => row_data[7].gsub!(/\%.*/,''),
                  :itm_ratio => row_data[8],
                  :itm_percent => row_data[9].gsub!(/\%.*/,'')
                }
              end
            end
          end
        end   
        roi_data   
      end
      
      def self.poker_site_value poker_site
        case poker_site
          when "pokerstars" then 2
        end
      end
      
      def self.get_raw_html player, poker_site, auth
        agent = WWW::Mechanize.new { |a| a.log = Logger.new("mech.log") }
        agent.user_agent_alias = 'Mac Safari'

        page = agent.get("http://www.officialpokerrankings.com/login.html")

        login_form = page.forms.first

        login_form.field_with(:name => "login_user").value = auth[:login]
        login_form.field_with(:name => "login_password").value = auth[:password]

        page = agent.submit(login_form)

        links = page.links_with(:text=>"Poker Rankings")

        page = links.first.click


        player_search = page.form_with(:name => "playersearchform2" )

        player_search.field_with(:name => "playersearch").value = player

        #the idiots use the select field option index to determine poker room
        player_search.field_with(:name => "pr").value = poker_site

        search_results = agent.submit(player_search)
        return search_results.body
      end
    end
  end
end