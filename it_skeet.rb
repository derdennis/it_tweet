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
require 'bskyrb'
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

# Configure my OAuth for BLuesky  authentification, the actual token lives in
# config.yml
client = Mastodon::REST::Client.new(base_url: CONFIG['mastodon_base_url'], bearer_token: CONFIG['mastodon_bearer_token'])

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
        text = "New Blogpost: #{i.title} #{i.link}"
        # Output the text
        puts text
        puts "=" * 50
        # Skeet the text
        client.create_status(text)

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
        toot_times[feed] = i.updated
        # Write the hash back to the cache file
        File.open( toot_times_file, 'w' ) do|f|
            f.write YAML.dump(toot_times)
        end

        # Sleep for 60 seconds
        sleep 60
    end # End if i.updated
end # End rss.entries.reverse
