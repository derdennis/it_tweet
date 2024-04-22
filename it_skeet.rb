#!/usr/bin/env ruby
# encoding: UTF-8

# This script takes information from an RSS feed and posts it as updates to
# BlueSky. If you have a website or blog, you can just run this script every
# time you make a new post and it'll automatically skeet about it.
#
# This script is heavily based on the twitterscript2 by Michael Morin which can
# be found at:
#
# http://ruby.about.com/od/networking/qt/twitterscript2.htm
#
# The main configuration options are expected in config.yml in the same
# directory as this script.

# Require some gems
require 'rubygems'
require 'minisky'
require 'simple-rss'
require 'open-uri'
require 'yaml'
require 'pony'

# Determine directory in which we live
@script_dir = File.expand_path(File.dirname(__FILE__))

# Load config from yaml-file, find it in the @script_dir
CONFIG = YAML.load_file("#{@script_dir}/config.yml") unless defined? CONFIG
# Feed is here
feed = CONFIG['feed']
# Cache file for the last checked time is here
skeet_times_file = @script_dir + "/" + CONFIG['bluesky_cache_file']

# If the skeet_times file exists, load the content from the yaml into a hash
# else create a new one and date it on 1970.
skeet_times = if File.exists?(skeet_times_file)
                YAML.load( File.read(skeet_times_file) )
            else
                Hash.new( Time.mktime('1970') )
            end

# Fetch and parse the feed with SimpleRSS
rss = SimpleRSS.parse open(feed)
# Tell me you're actually doing something...
print "Checking ", feed,  " for skeetable posts...", "\n"

# Walk the feed in reverse so we see the oldest entry first
rss.entries.reverse.each_with_index do|i,idx|
    #If the publication date is later than the date in our hash, put it's
    #values into the text for a new skeet.
p i.updated
p skeet_times[feed]
    if i.updated > skeet_times[feed]
		skeet_intro = "New Blogpost:"
        text = "#{skeet_intro} #{i.title} #{i.link}"
        # Output the text
        puts text
        puts "=" * 50
		# Let's make sure we are using UTF-8.
		text.force_encoding('UTF-8')

		# BlueSky does not use markup but rich text. Therefore we need to
		# explicitly tell it, where our link starts and ends.
		# Solution via: [Links don't seem to be clickable · Issue #10 · ShreyanJain9/bskyrb](https://github.com/ShreyanJain9/bskyrb/issues/10)
		link_pattern = /(https?):\/\/(\S+)/

		facets = []

		text.enum_for(:scan, link_pattern).each do |m|
		  index_start = Regexp.last_match.offset(0).first
		  index_end = Regexp.last_match.offset(0).last
		  m.compact!
		  path = "#{m[1]}#{m[2..].join("")}".strip
		  facets.push(
			"$type" => "app.bsky.richtext.facet",
			"index" => {
			  "byteStart" => index_start,
			  "byteEnd" => index_end,
			},
			"features" => [
			  {
				"uri" => URI.parse("#{m[0]}://#{path}").normalize.to_s, # this is the matched link
				"$type" => "app.bsky.richtext.facet#link",
			  },
			],
		  )
		end

		# Now that we have detected our link and it's length
		# and positions, we put it all together
		#puts facets.inspect
		puts "Here comes the skeet..."
		skeet_text = text.to_s
		puts skeet_text
		skeet_url = facets.first["features"].first["uri"].to_s
		puts skeet_url
		skeet_url_start = facets.first["index"]["byteStart"].to_i
		skeet_url_end = facets.first["index"]["byteEnd"].to_i
		puts skeet_url_start
		puts skeet_url_end

		# Configure Bluesky authentification, the actual values live in
		# config.yml
		class TransientClient
		  include Minisky::Requests

		  attr_reader :config, :host

		  def initialize(host, user)
			@host = host
			@config = { 'id' => user.gsub(/^@/, '') }
		  end

		  def ask_for_password
			#print "Enter password for @#{config['id']}: "
			@config['pass'] = CONFIG['bluesky_password'] #STDIN.noecho(&:gets).chomp
		  end

		  def save_config
			# ignore
		  end
		end

		host = CONFIG['bluesky_pds_host'] # 'bsky.social'
		handle = CONFIG['bluesky_username'] # '@derdennis.bsky.social'

		# create a client instance & read password
		bsky = TransientClient.new(host, handle)
		bsky.ask_for_password

		# fetch 1 post from the user's home feed. Why? Because otherwise
		# we will get a "400 Bad Request: Input/repo must be a string (Minisky::ClientErrorResponse)". This is why!
		bsky.get_request('app.bsky.feed.getTimeline', { limit: 1 })

		# We could also display the post (or the posts if we incrase the limit).
		# But we dont want to right now.
		#result['feed'].each do |r|
		  #reason = r['reason']
		  #reply = r['reply']
		  #post = r['post']

		  #if reason && reason['$type'] == 'app.bsky.feed.defs#reasonRepost'
			#puts "[Reposted by @#{reason['by']['handle']}]"
		  #end

		  #handle = post['author']['handle']
		  #timestamp = Time.parse(post['record']['createdAt']).getlocal

		  #puts "@#{handle} • #{timestamp}"
		  #puts

		  #if reply
			#puts "[in reply to @#{reply['parent']['author']['handle']}]"
			#puts
		  #end

		  #puts post['record']['text']
		  #puts
		  #puts "=" * 120
		  #puts
		#end

		# Use the skeet variables from above to create a skeet against the
		# BlueSky API and make sure the link is clickable.
		bsky.post_request('com.atproto.repo.createRecord', {
		  repo: bsky.user.did,
		  collection: 'app.bsky.feed.post',
		  record: {
			text: skeet_text,
			createdAt: Time.now.iso8601,
			langs: ["en"],
			facets: [
				{
				features: [
					{
					uri: skeet_url,
					"$type": "app.bsky.richtext.facet#link"
				  }
				],
				"index": {
				  "byteStart": skeet_url_start,
				  "byteEnd": skeet_url_end
				}
			  }
			]
		  }
		})

        # Notify me via mail that the post was skeeted
        message = "Hi #{CONFIG['recipient_name']}, \n\n I just skeeted the following skeet: \n\n" + text.to_s.force_encoding("utf-8") + ". \n\n Best, \n\n #{CONFIG['from_name']}"
        subject = "New Skeet skeeted: " + i.title.to_s.force_encoding("utf-8")
        # Pony configuration for googlemail, reads almost all values from
        # config.yml
        Pony.mail({
            :charset => "UTF-8",
            :text_part_charset => "UTF-8",
            :to => CONFIG['recipient_mail'],
            :from => CONFIG['from_mail'],
            :subject => subject,
            :body => message,
            :via => :smtp,
            :via_options => {
            :address              => CONFIG['smtp_server'],
            :port                 => CONFIG['smtp_port'],
            :enable_starttls_auto => true,
            :user_name            => CONFIG['smtp_user'],
            :password             => CONFIG['smtp_password'],
            :authentication       => :plain,
            :domain               => "localhost.localdomain"
        } # End pony via options
        }) # End Pony.mail

        # Update the hash with the time from the post just twittered
        skeet_times[feed] = i.updated
        # Write the hash back to the cache file
        File.open( skeet_times_file, 'w' ) do|f|
            f.write YAML.dump(skeet_times)
        end

        # Sleep for 60 seconds
        sleep 60
    end # End if i.updated
end # End rss.entries.reverse
